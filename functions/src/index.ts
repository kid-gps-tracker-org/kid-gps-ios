import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentCreated, onDocumentDeleted} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";

// Firebase Admin SDKの初期化
initializeApp();
const db = getFirestore();

// ============================================
// 設定
// ============================================
const ODPT_API_KEY = "dypmw04zpwyo763u35t7px7dc0p7l70m4w1ezsk65bmy8t1hr7ow1c4489axjec3";
const ODPT_API_URL = "https://api.odpt.org/api/v4/odpt:Bus";
const OPERATOR = "odpt.Operator:YokohamaMunicipal";
const BUS_ROUTE = "odpt.Busroute:YokohamaMunicipal.034";

// Firestoreコレクション名
const LOCATIONS_COLLECTION = "bus_locations";
const LATEST_LOCATION_COLLECTION = "latest_bus_location";

// ============================================
// バス位置データの型定義
// ============================================
interface BusLocation {
  latitude: number;
  longitude: number;
  timestamp: Timestamp;
  speed?: number;
  azimuth?: number;
  fromBusstopPole?: string;
  toBusstopPole?: string;
  operator: string;
  busRoute: string;
}

interface ODPTBusResponse {
  "geo:lat"?: number;
  "geo:long"?: number;
  "odpt:speed"?: number;
  "odpt:azimuth"?: number;
  "odpt:fromBusstopPole"?: string;
  "odpt:toBusstopPole"?: string;
  "odpt:operator"?: string;
  "odpt:busroute"?: string;
}

// ============================================
// バス位置取得（毎分実行）
// ============================================
export const fetchBusLocation = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Asia/Tokyo",
    region: "asia-northeast1",
    maxInstances: 1,
  },
  async (event) => {
    try {
      logger.info("🚌 バス位置取得開始...");

      // 🆕 1. 前回の位置データを取得
      const previousLocationSnapshot = await db
        .collection(LOCATIONS_COLLECTION)
        .orderBy("timestamp", "desc")
        .limit(1)
        .get();

      const previousLocation = previousLocationSnapshot.empty ?
        null :
        previousLocationSnapshot.docs[0].data() as BusLocation;

      // 2. ODPT APIからバスデータを取得
      const response = await fetch(
        `${ODPT_API_URL}?acl:consumerKey=${ODPT_API_KEY}&odpt:operator=${OPERATOR}&odpt:busroute=${BUS_ROUTE}`
      );

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const buses: ODPTBusResponse[] = await response.json();
      logger.info(`📡 APIレスポンス: ${buses.length}台のバスデータ受信`);

      if (buses.length === 0) {
        logger.warn("⚠️ バスデータが見つかりません");
        return;
      }

      // 最初のバスデータを使用
      const bus = buses[0];

      if (!bus["geo:lat"] || !bus["geo:long"]) {
        logger.warn("⚠️ 位置情報がありません");
        return;
      }

      // 3. Firestoreに保存するデータ
      const locationData: BusLocation = {
        latitude: bus["geo:lat"],
        longitude: bus["geo:long"],
        timestamp: Timestamp.now(),
        operator: OPERATOR,
        busRoute: BUS_ROUTE,
      };

      // 🆕 4. 速度を計算（前回データがあれば）
      if (previousLocation) {
        const calculatedSpeed = calculateSpeed(previousLocation, locationData);

        if (calculatedSpeed !== null) {
          locationData.speed = calculatedSpeed;
          logger.info(`✅ 計算速度: ${calculatedSpeed.toFixed(1)} km/h`);
        } else {
          logger.info("ℹ️ 速度計算不可（初回または異常値）");
        }
      } else {
        logger.info("ℹ️ 初回データのため速度計算なし");
      }

      // 5. APIから速度データがあれば、それも記録（比較用）
      if (bus["odpt:speed"] !== undefined) {
        logger.info(`📊 API速度: ${bus["odpt:speed"]} km/h`);
        // 本番環境では計算速度を使用するため、API速度は保存しない
      }

      // 6. その他のデータを追加
      if (bus["odpt:azimuth"] !== undefined) {
        locationData.azimuth = bus["odpt:azimuth"];
      }
      if (bus["odpt:fromBusstopPole"] !== undefined) {
        locationData.fromBusstopPole = bus["odpt:fromBusstopPole"];
      }
      if (bus["odpt:toBusstopPole"] !== undefined) {
        locationData.toBusstopPole = bus["odpt:toBusstopPole"];
      }

      // ✅ 7. 履歴データとして保存（自動ID）
      await db.collection(LOCATIONS_COLLECTION).add(locationData);

      // ✅ 8. 最新位置として保存（固定ドキュメントID）
      await db.collection(LATEST_LOCATION_COLLECTION)
        .doc("current")
        .set(locationData);

      logger.info("✅ 位置データ保存成功:", {
        lat: locationData.latitude,
        lng: locationData.longitude,
        speed: locationData.speed ? `${locationData.speed.toFixed(1)} km/h` : "なし",
        time: locationData.timestamp.toDate(),
      });
    } catch (error) {
      logger.error("❌ エラー発生:", error);
    }
  }
);
// ============================================
// 古いデータの自動削除（毎日実行）
// ============================================
export const cleanOldLocations = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Asia/Tokyo",
    region: "asia-northeast1",
    maxInstances: 1,
  },
  async (event) => {
    try {
      logger.info("🗑️ 古いデータ削除開始...");

      // 30日前の日付を計算
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      // 30日より古いデータを取得
      const snapshot = await db
        .collection(LOCATIONS_COLLECTION)
        .where("timestamp", "<", Timestamp.fromDate(thirtyDaysAgo))
        .limit(500)
        .get();

      if (snapshot.empty) {
        logger.info("削除するデータがありません");
        return;
      }

      // バッチ削除
      const batch = db.batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      await batch.commit();

      logger.info(`✅ ${snapshot.size}件のデータを削除しました`);
    } catch (error) {
      logger.error("❌ エラー発生:", error);
    }
  }
);

// ============================================
// セーフゾーン判定機能
// ============================================

/**
 * 距離計算関数(Haversine公式)
 * @param {number} lat1 - 緯度1
 * @param {number} lon1 - 経度1
 * @param {number} lat2 - 緯度2
 * @param {number} lon2 - 経度2
 * @return {number} 2点間の距離(メートル)
 */
function calculateDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371000; // 地球の半径(メートル)
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

/**
 * 速度を計算する関数
 * @param {BusLocation} previousLocation - 前回の位置データ
 * @param {BusLocation} currentLocation - 現在の位置データ
 * @return {number | null} 速度（km/h）、計算できない場合はnull
 */
function calculateSpeed(
  previousLocation: BusLocation,
  currentLocation: BusLocation
): number | null {
  // 1. 距離を計算（メートル）
  const distance = calculateDistance(
    previousLocation.latitude,
    previousLocation.longitude,
    currentLocation.latitude,
    currentLocation.longitude
  );

  // 2. 時間差を計算（秒）
  const previousTime = previousLocation.timestamp.toDate();
  const currentTime = currentLocation.timestamp.toDate();
  const timeIntervalSeconds =
    (currentTime.getTime() - previousTime.getTime()) / 1000;

  // 3. 時間差が0または負の場合は計算不可
  if (timeIntervalSeconds <= 0) {
    logger.warn(`⚠️ 時間差が無効: ${timeIntervalSeconds}秒`);
    return null;
  }

  // 4. 速度を計算
  const speedMps = distance / timeIntervalSeconds; // m/s
  const speedKmh = speedMps * 3.6; // km/h

  // 5. 異常値を除外
  if (speedKmh > 300) {
    const msg = `⚠️ 異常な速度値: ${speedKmh.toFixed(1)} km/h（300超）`;
    logger.warn(msg);
    return null;
  }

  // 6. 微小な移動は停止とみなす（5m未満で60秒以内）
  if (distance < 5 && timeIntervalSeconds < 60) {
    return 0;
  }

  // 7. ログ出力
  const logMsg = `📊 速度: 距離=${distance.toFixed(1)}m ` +
    `時間=${timeIntervalSeconds.toFixed(1)}秒 ` +
    `速度=${speedKmh.toFixed(1)}km/h`;
  logger.info(logMsg);

  return speedKmh;
}

/**
 * セーフゾーン入退場判定
 * locations/{childId}/history/{locationId} にドキュメントが作成されたときに実行
 */
export const checkSafeZone = onDocumentCreated(
  {
    document: "bus_locations/{locationId}",
    region: "asia-northeast1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("データが存在しません");
      return;
    }

    const location = snapshot.data();
    // TODO: 将来的に複数の子供を管理する場合は、location.childIdを使用
    const childId = "test-child-001";

    logger.info(`📍 位置データ受信: childId=${childId}, lat=${location.latitude}, lng=${location.longitude}`);

    try {
      // アクティブなセーフゾーンを取得
      const zonesSnapshot = await db
        .collection("safe_zones")
        .where("childId", "==", childId)
        .where("isActive", "==", true)
        .get();

      if (zonesSnapshot.empty) {
        logger.info("セーフゾーンなし");
        return;
      }

      logger.info(`✅ セーフゾーン数: ${zonesSnapshot.size}`);

      const batch = db.batch();

      for (const zoneDoc of zonesSnapshot.docs) {
        const zone = zoneDoc.data();

        // 距離計算
        const distance = calculateDistance(
          location.latitude,
          location.longitude,
          zone.center.latitude,
          zone.center.longitude
        );

        const isInside = distance <= zone.radius;

        // 前回のイベントを取得
        const lastEventSnapshot = await db
          .collection("zone_events")
          .where("safeZoneId", "==", zoneDoc.id)
          .where("childId", "==", childId)
          .orderBy("timestamp", "desc")
          .limit(1)
          .get();

        const lastEvent = lastEventSnapshot.empty ? null : lastEventSnapshot.docs[0].data();
        const wasInside = lastEvent?.eventType === "enter";

        logger.info(`🔵 ゾーン: ${zone.name}, 距離: ${distance.toFixed(1)}m, 内側: ${isInside}, 前回: ${wasInside}`);

        // 入場判定
        if (isInside && !wasInside) {
          logger.info(`✅ 入場検知: ${zone.name}`);
          const eventRef = db.collection("zone_events").doc();
          batch.set(eventRef, {
            safeZoneId: zoneDoc.id,
            safeZoneName: zone.name,
            childId: childId,
            eventType: "enter",
            timestamp: Timestamp.now(),
            location: {
              latitude: location.latitude,
              longitude: location.longitude,
            },
            notificationSent: false,
          });
        }

        // 退場判定
        if (!isInside && wasInside) {
          logger.info(`🚪 退場検知: ${zone.name}`);
          const eventRef = db.collection("zone_events").doc();
          batch.set(eventRef, {
            safeZoneId: zoneDoc.id,
            safeZoneName: zone.name,
            childId: childId,
            eventType: "exit",
            timestamp: Timestamp.now(),
            location: {
              latitude: location.latitude,
              longitude: location.longitude,
            },
            notificationSent: false,
          });
        }
      }

      // イベントを一括保存
      await batch.commit();
      logger.info("💾 イベント保存完了");
    } catch (error) {
      logger.error("❌ セーフゾーン判定エラー:", error);
    }
  }
);

/**
 * セーフゾーン削除時のクリーンアップ
 */
export const cleanupSafeZoneEvents = onDocumentDeleted(
  {
    document: "safe_zones/{zoneId}",
    region: "asia-northeast1",
  },
  async (event) => {
    const zoneId = event.params.zoneId;
    const snapshot = event.data;
    if (!snapshot) return;

    const zoneName = snapshot.data().name;

    logger.info(`🗑️ セーフゾーン削除: ${zoneName} (${zoneId})`);

    try {
      // 関連するイベントを削除
      const eventsSnapshot = await db
        .collection("zone_events")
        .where("safeZoneId", "==", zoneId)
        .get();

      if (eventsSnapshot.empty) {
        logger.info("削除するイベントなし");
        return;
      }

      const batch = db.batch();
      eventsSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      logger.info(`✅ ${eventsSnapshot.size}件のイベントを削除`);
    } catch (error) {
      logger.error("❌ クリーンアップエラー:", error);
    }
  }
);

/**
 * 毎日0時に実行:古い位置履歴データを削除
 * 保持期間: 24時間
 */
export const cleanupOldLocationHistory = onSchedule(
  {
    schedule: "0 0 * * *", // 毎日0時(JST)
    timeZone: "Asia/Tokyo",
    region: "asia-northeast1",
  },
  async (event) => {
    logger.info("🧹 位置履歴クリーンアップ開始");

    try {
      // 24時間前の時刻を計算
      const twentyFourHoursAgo = new Date();
      twentyFourHoursAgo.setHours(twentyFourHoursAgo.getHours() - 24);

      // 24時間より古いデータを取得
      const oldDataQuery = await db
        .collection("bus_locations")
        .where("timestamp", "<", Timestamp.fromDate(twentyFourHoursAgo))
        .get();

      logger.info(`📊 削除対象: ${oldDataQuery.size}件`);

      if (oldDataQuery.size === 0) {
        logger.info("✅ 削除対象なし");
        return;
      }

      // バッチ削除(最大500件ずつ)
      const batchSize = 500;
      const batches = [];

      for (let i = 0; i < oldDataQuery.size; i += batchSize) {
        const batch = db.batch();
        const docs = oldDataQuery.docs.slice(i, i + batchSize);

        docs.forEach((doc) => {
          batch.delete(doc.ref);
        });

        batches.push(batch.commit());
      }

      await Promise.all(batches);

      logger.info(`✅ 位置履歴削除完了: ${oldDataQuery.size}件`);
    } catch (error) {
      logger.error("❌ 位置履歴削除エラー:", error);
    }
  }
);

/**
 * 毎日0時5分に実行:古いセーフゾーンイベントを削除
 * 保持期間: 30日
 */
export const cleanupOldZoneEvents = onSchedule(
  {
    schedule: "5 0 * * *", // 毎日0時5分(JST)
    timeZone: "Asia/Tokyo",
    region: "asia-northeast1",
  },
  async (event) => {
    logger.info("🧹 セーフゾーンイベントクリーンアップ開始");

    try {
      // 30日前の時刻を計算
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      // 30日より古いデータを取得
      const oldEventsQuery = await db
        .collection("zone_events")
        .where("timestamp", "<", Timestamp.fromDate(thirtyDaysAgo))
        .get();

      logger.info(`📊 削除対象: ${oldEventsQuery.size}件`);

      if (oldEventsQuery.size === 0) {
        logger.info("✅ 削除対象なし");
        return;
      }

      // バッチ削除(最大500件ずつ)
      const batchSize = 500;
      const batches = [];

      for (let i = 0; i < oldEventsQuery.size; i += batchSize) {
        const batch = db.batch();
        const docs = oldEventsQuery.docs.slice(i, i + batchSize);

        docs.forEach((doc) => {
          batch.delete(doc.ref);
        });

        batches.push(batch.commit());
      }

      await Promise.all(batches);

      logger.info(`✅ セーフゾーンイベント削除完了: ${oldEventsQuery.size}件`);
    } catch (error) {
      logger.error("❌ セーフゾーンイベント削除エラー:", error);
    }
  }
);

