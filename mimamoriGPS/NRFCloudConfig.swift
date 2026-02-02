//
//  NRFCloudConfig.swift
//  mimamoriGPS
//
//  nRF Cloud API設定
//

import Foundation

/// nRF Cloud API設定
struct NRFCloudConfig {
    /// API Base URL
    static let baseURL = "https://api.nrfcloud.com"
    
    /// API Key
    static var apiKey: String {
        return UserDefaults.standard.string(forKey: "nrf_cloud_api_key") ?? ""
    }
    
    /// Device ID
    static var deviceID: String {
        return UserDefaults.standard.string(forKey: "nrf_cloud_device_id") ?? ""
    }
    
    /// API Keyを保存
    static func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "nrf_cloud_api_key")
        print("✅ nRF Cloud API Key保存完了")
    }
    
    /// Device IDを保存
    static func saveDeviceID(_ deviceID: String) {
        UserDefaults.standard.set(deviceID, forKey: "nrf_cloud_device_id")
        print("✅ nRF Cloud Device ID保存完了")
    }
    
    /// 設定が完了しているか確認
    static func isConfigured() -> Bool {
        return !apiKey.isEmpty && !deviceID.isEmpty
    }
    
    /// 設定をリセット（デバッグ用）
    static func resetConfig() {
        UserDefaults.standard.removeObject(forKey: "nrf_cloud_api_key")
        UserDefaults.standard.removeObject(forKey: "nrf_cloud_device_id")
        print("🗑️ nRF Cloud設定をリセットしました")
    }
}
