//
//  PushNotificationHandler.swift
//  mimamoriGPS
//
//  AWS REST API プッシュ通知ハンドラー
//  API仕様書 セクション6 準拠
//

import Foundation
import UserNotifications

class PushNotificationHandler {
    // MARK: - Singleton
    static let shared = PushNotificationHandler()
    
    private init() {}
    
    // MARK: - Notification Handling
    
    /// プッシュ通知のペイロードを処理
    /// - Parameter userInfo: APNsから受信したペイロード
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        print("📬 プッシュ通知受信")
        print("   Payload: \(userInfo)")
        
        // dataフィールドを抽出
        guard let data = userInfo["data"] as? [String: Any] else {
            print("⚠️ dataフィールドが見つかりません")
            return
        }
        
        // 通知タイプを確認
        guard let typeString = data["type"] as? String,
              let type = PushNotificationData.NotificationType(rawValue: typeString) else {
            print("⚠️ 通知タイプが不正です")
            return
        }
        
        print("📍 通知タイプ: \(type.rawValue)")
        
        // データを抽出
        guard let deviceId = data["deviceId"] as? String,
              let zoneId = data["zoneId"] as? String,
              let zoneName = data["zoneName"] as? String,
              let locationDict = data["location"] as? [String: Any],
              let detectedAt = data["detectedAt"] as? String else {
            print("❌ 必須フィールドが不足しています")
            return
        }
        
        // Location を構築
        guard let lat = locationDict["lat"] as? Double,
              let lon = locationDict["lon"] as? Double,
              let accuracy = locationDict["accuracy"] as? Double,
              let sourceString = locationDict["source"] as? String,
              let source = Location.LocationSource(rawValue: sourceString),
              let timestamp = locationDict["timestamp"] as? String else {
            print("❌ 位置情報の形式が不正です")
            return
        }
        
        let location = Location(
            lat: lat,
            lon: lon,
            accuracy: accuracy,
            source: source,
            timestamp: timestamp
        )
        
        // PushNotificationData を構築
        let notificationData = PushNotificationData(
            type: type,
            deviceId: deviceId,
            zoneId: zoneId,
            zoneName: zoneName,
            location: location,
            detectedAt: detectedAt
        )
        
        // 通知データを処理
        handlePushNotificationData(notificationData)
    }
    
    /// PushNotificationData を処理
    private func handlePushNotificationData(_ data: PushNotificationData) {
        print("✅ プッシュ通知データ処理")
        print("   デバイスID: \(data.deviceId)")
        print("   ゾーン: \(data.zoneName)")
        print("   タイプ: \(data.type.rawValue)")
        print("   位置: (\(data.location.lat), \(data.location.lon))")
        
        // NotificationCenterで他の部分に通知
        NotificationCenter.default.post(
            name: .safeZoneEventReceived,
            object: nil,
            userInfo: [
                "type": data.type.rawValue,
                "deviceId": data.deviceId,
                "zoneId": data.zoneId,
                "zoneName": data.zoneName,
                "location": data.location,
                "detectedAt": data.detectedAt
            ]
        )
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let safeZoneEventReceived = Notification.Name("safeZoneEventReceived")
}
