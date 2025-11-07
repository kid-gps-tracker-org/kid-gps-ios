//
//  BusLocation.swift
//  mimamoriGPS
//
//  Firestoreのバス位置データモデル
//

import Foundation
import FirebaseFirestore
import SwiftUI  // 🆕 追加

struct BusLocation: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    let latitude: Double
    let longitude: Double
    let timestamp: Timestamp
    let speed: Double?
    let azimuth: Double?
    let fromBusstopPole: String?
    let toBusstopPole: String?
    let busOperator: String?
    let busRoute: String?
    
    // 地図表示用に座標を返す
    var coordinate: (latitude: Double, longitude: Double) {
        return (latitude, longitude)
    }
    
    // タイムスタンプをDateに変換
    var date: Date {
        return timestamp.dateValue()
    }
    
    // デバッグ用
    var description: String {
        return """
        緯度: \(latitude)
        経度: \(longitude)
        時刻: \(date)
        速度: \(speed ?? 0) km/h
        """
    }
    // MARK: - Equatable
        
    static func == (lhs: BusLocation, rhs: BusLocation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.latitude == rhs.latitude &&
               lhs.longitude == rhs.longitude &&
               lhs.timestamp.dateValue() == rhs.timestamp.dateValue()
    }
}

// MARK: - Transport Mode Detection

extension BusLocation {
    /// 移動手段の判定
    enum TransportMode {
        case walking  // 徒歩 (0-10 km/h)
        case vehicle  // 乗り物 (10+ km/h)
    }
    
    /// 速度から移動手段を判定
    var transportMode: TransportMode {
        guard let speed = speed else {
            return .walking  // 速度不明の場合は徒歩扱い
        }
        
        return speed < 10.0 ? .walking : .vehicle
    }
    
    /// マーカー色を取得
    var markerColor: Color {
        switch transportMode {
        case .walking:
            return .blue  // 🔵 徒歩: 青
        case .vehicle:
            return .red   // 🔴 乗り物: 赤
        }
    }
}
