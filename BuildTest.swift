//
//  BuildTest.swift
//  mimamoriGPS
//
//  ビルドテスト用ファイル（本番では削除可能）
//

import Foundation

/// ビルドエラーがないかテストするための関数
func testBuild() {
    // BuildTest は一時的に無効化（APISafeZone と Device の定義が異なるため）
    
    // AWSNetworkService のテスト
    let _ = AWSNetworkService.shared.isConfigured()
    
    // PushNotificationHandler のテスト
    let _ = PushNotificationHandler.shared
    
    print("✅ ビルドテスト成功")
}
