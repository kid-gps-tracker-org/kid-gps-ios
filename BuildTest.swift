//
//  BuildTest.swift
//  mimamoriGPS
//
//  ビルドテスト用ファイル（本番では削除可能）
//

import Foundation

/// ビルドエラーがないかテストするための関数
func testBuild() {
    // API Models のインスタンス化テスト
    let _ = Location(
        lat: 35.681236,
        lon: 139.767125,
        accuracy: 10.5,
        source: .gnss,
        timestamp: "2026-02-05T12:30:00.000Z"
    )
    
    let _ = Temperature(
        value: 23.5,
        timestamp: "2026-02-05T12:30:05.000Z"
    )
    
    let _ = Coordinate(lat: 35.681236, lon: 139.767125)
    
    let _ = APISafeZone(
        zoneId: "550e8400-e29b-41d4-a716-446655440000",
        name: "自宅",
        center: Coordinate(lat: 35.681236, lon: 139.767125),
        radius: 200,
        enabled: true,
        createdAt: "2026-02-01T00:00:00.000Z",
        updatedAt: "2026-02-01T00:00:00.000Z"
    )
    
    let _ = Device(
        deviceId: "nrf-352656100123456",
        lastLocation: nil,
        lastTemperature: nil,
        inSafeZone: false,
        firmwareVersion: nil,
        lastSeen: nil
    )
    
    // AWSNetworkService のテスト
    let _ = AWSNetworkService.shared.isConfigured()
    
    // PushNotificationHandler のテスト
    let _ = PushNotificationHandler.shared
    
    // FirestoreService DataSource のテスト
    let _ = FirestoreService.DataSource.firebase
    let _ = FirestoreService.DataSource.nrfCloudDirect
    let _ = FirestoreService.DataSource.awsBackend
    
    print("✅ ビルドテスト成功")
}
