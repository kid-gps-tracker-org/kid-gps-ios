//
//  DeviceLocation.swift
//  mimamoriGPS
//
//  AWS REST API用位置情報モデル
//  公共交通DB・BusLocation完全削除版
//

import Foundation
import CoreLocation
import SwiftUI

/// デバイス位置情報（地図表示用）
struct DeviceLocation: Identifiable, Equatable {
    let id: String
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let source: LocationSource
    let timestamp: Date
    
    enum LocationSource: String {
        case gnss = "GNSS"
        case groundFix = "GROUND_FIX"
    }
    
    // MARK: - Computed Properties
    
    /// CLLocationCoordinate2Dに変換
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// 座標タプル（後方互換性）
    var coordinateTuple: (latitude: Double, longitude: Double) {
        (latitude, longitude)
    }
    
    /// 測位方式による色分け
    var markerColor: Color {
        switch source {
        case .gnss:
            return .blue  // 🔵 GNSS: 青
        case .groundFix:
            return .orange  // 🟠 地上測位: オレンジ
        }
    }
    
    /// 精度によるマーカーサイズ
    var markerSize: CGFloat {
        if accuracy < 10 {
            return 12  // 高精度
        } else if accuracy < 50 {
            return 10  // 中精度
        } else {
            return 8   // 低精度
        }
    }
    
    // MARK: - Initializers
    
    init(
        id: String = UUID().uuidString,
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        source: LocationSource,
        timestamp: Date
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.source = source
        self.timestamp = timestamp
    }
    
    /// AWS APIのLocation型から変換
    init(from location: Location, deviceId: String = "") {
        self.id = deviceId.isEmpty ? UUID().uuidString : deviceId
        self.latitude = location.lat
        self.longitude = location.lon
        self.accuracy = location.accuracy
        self.source = LocationSource(rawValue: location.source.rawValue) ?? .gnss
        self.timestamp = location.date ?? Date()
    }
    
    // MARK: - Equatable
    
    static func == (lhs: DeviceLocation, rhs: DeviceLocation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.latitude == rhs.latitude &&
               lhs.longitude == rhs.longitude &&
               lhs.timestamp == rhs.timestamp
    }
}

// MARK: - HistoryEntry からの変換

extension DeviceLocation {
    /// HistoryEntry（位置情報）から変換
    init?(from historyEntry: HistoryEntry, deviceId: String = "") {
        // 位置情報のみ（温度データは除外）
        guard historyEntry.messageType != .temp,
              let lat = historyEntry.lat,
              let lon = historyEntry.lon,
              let accuracy = historyEntry.accuracy else {
            return nil
        }
        
        let source: LocationSource
        switch historyEntry.messageType {
        case .gnss:
            source = .gnss
        case .groundFix:
            source = .groundFix
        case .temp:
            return nil  // 温度データは位置情報ではない
        }
        
        self.id = deviceId.isEmpty ? UUID().uuidString : "\(deviceId)-\(historyEntry.timestamp)"
        self.latitude = lat
        self.longitude = lon
        self.accuracy = accuracy
        self.source = source
        self.timestamp = historyEntry.date ?? Date()
    }
}
