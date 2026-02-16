# AWS REST API 統合ガイド

**最終更新日**: 2026-02-16  
**ドキュメントバージョン**: v1.3  

---

## 概要

このiPhoneアプリは、AWS REST API仕様書 v1.0 に準拠した実装を含んでいます。
AWS REST API を唯一のデータソースとして使用し、デバイスの位置情報・温度情報・セーフゾーン管理を行います。

---

## ファイル構成

### データモデル

| ファイル名 | 説明 |
|-----------|------|
| `APIModels.swift` | API仕様書の全データ型定義 |
| `BusLocation.swift` | 地図表示用位置情報モデル |
| `DeviceLocation.swift` | デバイス位置情報モデル |
| `SafeZone.swift` | セーフゾーンモデル |

### サービス

| ファイル名 | 説明 |
|-----------|------|
| `AWSNetworkService.swift` | AWS REST API通信サービス（シングルトン） |
| `FirestoreService.swift` | アプリ全体の状態管理サービス（シングルトン） |
| `DataService.swift` | AWS REST APIデータサービス（補助） |

### 画面

| ファイル名 | 説明 |
|-----------|------|
| `ContentView.swift` | タブバー・ルート画面 |
| `MapView.swift` | 地図・位置情報表示 |
| `SettingsView.swift` | 設定ハブ画面（新規） |
| `SafeZoneListView.swift` | セーフゾーン一覧 |
| `SafeZoneEditView.swift` | セーフゾーン追加・編集 |
| `NRFCloudSettingsView.swift` | AWS API設定画面 |
| `ZoneEventListView.swift` | セーフゾーン入退場履歴 |
| `ZoneHistoryView.swift` | ゾーン履歴詳細 |

---

## 実装済み機能

### API エンドポイント（全10個）

| # | エンドポイント | 用途 | 使用箇所 |
|---|--------------|------|---------|
| 1 | `GET /devices` | デバイス一覧・位置・温度取得 | `FirestoreService.fetchLocationFromAWS` |
| 2 | `GET /devices/{deviceId}/location` | 最新位置情報 | `AWSNetworkService.getLocation` |
| 3 | `GET /devices/{deviceId}/temperature` | 最新温度情報 | `AWSNetworkService.getTemperature` |
| 4 | `GET /devices/{deviceId}/history` | 履歴取得 | `FirestoreService.fetchLocationHistory` |
| 5 | `GET /devices/{deviceId}/safezones` | セーフゾーン一覧 | `FirestoreService.fetchSafeZonesFromAWS` |
| 6 | `PUT /devices/{deviceId}/safezones` | セーフゾーン作成・更新 | `FirestoreService.addSafeZone / updateSafeZone` |
| 7 | `DELETE /devices/{deviceId}/safezones/{zoneId}` | セーフゾーン削除 | `FirestoreService.deleteSafeZone` |
| 8 | `GET /devices/{deviceId}/firmware` | ファームウェア情報 | `AWSNetworkService.getFirmware` |
| 9 | `POST /devices/{deviceId}/firmware/update` | ファームウェア更新 | `AWSNetworkService.updateFirmware` |
| 10 | `GET /devices/{deviceId}/firmware/status` | FOTAジョブ状態 | `AWSNetworkService.getFirmwareStatus` |

### データ取得フロー（位置・温度）

```
60秒ごと（ポーリング）
    ↓
GET /devices
    ↓
Device.lastLocation  → FirestoreService.currentBusLocation
Device.lastTemperature → FirestoreService.lastTemperature
    ↓
MapView の BusInfoCard に反映
```

### セーフゾーン CRUD（楽観的更新）

```
ユーザーが保存ボタンを押す
    ↓
① ローカルの safeZones を即座に更新（楽観的更新）
    ↓ 地図に即反映
② バックグラウンドで AWS API にリクエスト
    ↓
③ 成功 → GET /safezones で再同期
   失敗 → ローカルの変更をロールバック
```

---

## UI 構成

### タブ構成

| タブ番号 | ラベル | アイコン | 内容 |
|---------|-------|---------|------|
| 0 | 今日 | calendar | 日付選択・軌跡表示日指定 |
| 1 | 地図 | map | リアルタイム位置・温度・セーフゾーン表示 |
| 2 | 履歴 | clock | セーフゾーン入退場履歴 |
| 3 | 設定 | gearshape | 設定ハブ（セーフゾーン・AWS API設定） |

### 設定タブ（SettingsView）

設定項目を `NavigationLink` で管理する拡張可能なハブ構造。

```
設定
 ├── みまもり設定
 │    └── セーフゾーン → SafeZoneListView（設定件数をサブタイトルに表示）
 ├── 接続
 │    └── AWS API設定 → NRFCloudSettingsView（未設定時は「要設定」バッジ）
 └── アプリ情報
      └── バージョン（表示のみ）
```

**今後の設定項目追加方法**: `SettingsView.swift` の該当 `Section` に `NavigationLink` 行を追加するだけ。

**ナビゲーションリセット仕様**: 設定タブから離れるたびに `SettingsView` が再生成され、常にトップ画面から始まる（`ContentView` の `settingsResetID` による制御）。

### 地図画面（MapView）の BusInfoCard

```
┌──────────────────────────────────┐
│ 👤 [デバイス表示名]          [GPS] │
│ ─────────────────────────────── │
│ 🕐 14:21:46        🌡️ 26.4℃    │
└──────────────────────────────────┘
```

- 温度は `Device.lastTemperature` から取得（`GET /devices` レスポンス）
- 温度の色分け：〜10℃ 青 / 〜25℃ 緑 / 〜30℃ オレンジ / 30℃〜 赤
- 温度データが `null` の場合は温度欄を非表示

### セーフゾーン編集画面（SafeZoneEditView）

- **既存ゾーン**：グレーの半透明円 + ゾーン名ラベルで表示（参照用）
- **編集中ゾーン**：青い円で表示
- 既存ゾーンはタップを透過（地図タップ操作を妨げない）
- 編集中のゾーン自身は既存ゾーン表示から除外（二重表示防止）

---

## FirestoreService の設計

### インスタンス共有

`FirestoreService` は `ContentView` で `@StateObject` として1つだけ生成し、すべての子ビューに `@ObservedObject` として渡す。

```
ContentView
 └── @StateObject firestoreService（唯一のインスタンス）
      ├── MapView(firestoreService: firestoreService)
      ├── ZoneEventListView(firestoreService: firestoreService)
      └── SettingsView(firestoreService: firestoreService)
           └── SafeZoneListView(firestoreService: firestoreService)
                └── SafeZoneEditView(firestoreService: firestoreService)
```

### Published プロパティ

| プロパティ | 型 | 説明 |
|-----------|---|------|
| `currentBusLocation` | `BusLocation?` | 最新位置情報 |
| `lastTemperature` | `Temperature?` | 最新温度情報 |
| `isLoading` | `Bool` | ローディング状態 |
| `errorMessage` | `String?` | エラーメッセージ |
| `locationHistory` | `[BusLocation]` | 軌跡履歴 |
| `safeZones` | `[SafeZone]` | セーフゾーン一覧 |
| `zoneEvents` | `[ZoneEvent]` | 入退場イベント履歴 |

### ポーリング間隔

| 対象 | 間隔 |
|------|------|
| 位置情報・温度 | 60秒 |
| セーフゾーン | 300秒（5分） |
| 入退場イベント | 300秒（5分） |

---

## API仕様書との対応

### タイムスタンプ形式（1.2節）
```swift
// ISO 8601 / UTC / ミリ秒精度
ISO8601DateFormatter.withFractionalSeconds
// 例: "2026-02-05T12:34:56.789Z"
```

### 座標系（1.4節）
```swift
struct Coordinate {
    let lat: Double  // -90.0 〜 90.0
    let lon: Double  // -180.0 〜 180.0
}
```

### null ハンドリング（1.3節）
```swift
let lastLocation: Location?      // null → nil
let lastTemperature: Temperature? // null → nil（温度UI非表示）
let firmwareVersion: String?      // null → nil
```

### エラーハンドリング（3.9節、5節）
```swift
struct ApiError: Codable {
    let error: ErrorDetail
    struct ErrorDetail {
        let code: String    // SCREAMING_SNAKE_CASE
        let message: String
    }
}
```

---

## 設定方法

1. アプリ下タブの「設定」→「AWS API設定」を開く
2. **Base URL**: `https://{api-id}.execute-api.ap-northeast-1.amazonaws.com/dev`
3. **API Key**: API Gatewayで発行されたAPIキー
4. **Device ID**: デバイスのID（例: `nrf-352656100123456`）
5. **表示名**: 地図カードに表示される名前
6. 「設定を保存」をタップ

### UserDefaults に保存される設定

| キー | 内容 |
|-----|------|
| `aws_base_url` | AWS API GatewayのベースURL |
| `aws_api_key` | API認証キー |
| `nrf_device_id` | デバイスID |
| `device_display_name` | 地図カードに表示される名前 |

---

## プッシュ通知

### APNsペイロード形式（6.1、6.2節）

**ZONE_EXIT（セーフゾーン離脱）/ ZONE_ENTER（帰還）共通フォーマット:**
```json
{
  "aps": {
    "alert": { "title": "セーフゾーンアラート", "body": "..." },
    "sound": "default",
    "badge": 1
  },
  "data": {
    "type": "ZONE_EXIT",
    "deviceId": "nrf-352656100123456",
    "zoneId": "550e8400-...",
    "zoneName": "自宅",
    "location": { "lat": 35.0, "lon": 139.0, "accuracy": 10.0, "source": "GNSS", "timestamp": "..." },
    "detectedAt": "2026-02-05T12:30:05.000Z"
  }
}
```

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|-----|------|------|
| 「AWS APIの設定が完了していません」 | Base URL / API Key 未設定 | 設定タブ → AWS API設定 で入力 |
| `[MISSING_API_KEY]` エラー | API Key 誤り | AWS API Gatewayで確認 |
| `[DEVICE_NOT_FOUND]` エラー | Device ID 誤り | nRF CloudのデバイスIDを確認 |
| 温度が表示されない | `lastTemperature` が null | デバイスが温度センサーを持つか確認 |
| セーフゾーンが地図に反映されない | FirestoreService のインスタンスが複数 | `@ObservedObject` で親から渡しているか確認 |

---

## 今後の拡張予定

- [ ] 温度グラフ表示（履歴ベース）
- [ ] ファームウェア更新UI
- [ ] オフライン対応（キャッシュ）
- [ ] プッシュ通知履歴表示
