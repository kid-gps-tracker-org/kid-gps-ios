//
//  BusLocation.swift
//  mimamoriGPS
//
//  デバイス位置情報モデル（Firebase削除版）
//

import Foundation
import CoreLocation
import SwiftUI

struct BusLocation: Identifiable, Codable, Equatable {
    var id: String
    var latitude: Double
    var longitude: Double
    var timestamp: Timestamp
    var speed: Double?
    var azimuth: Double?
    var fromBusstopPole: String?
    var toBusstopPole: String?
    var busOperator: String?
    var busRoute: String?

    /// 測位方式（GNSS / GROUND_FIX）
    var locationSource: LocationSource

    enum LocationSource: String, Codable {
        case gnss       = "GNSS"
        case groundFix  = "GROUND_FIX"
    }

    // MARK: - Computed Properties

    /// GNSS 測位かどうか
    var isGNSS: Bool { locationSource == .gnss }

    /// CLLocationCoordinate2D に変換
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// タイムスタンプをDateに変換
    var date: Date {
        timestamp.dateValue()
    }
    
    /// 速度から移動モードを判定
    var transportMode: TransportMode {
        guard let speed = speed else { return .walking }  // speedがない場合は徒歩とみなす
        return speed < 10 ? .walking : .vehicle
    }
    
    /// マーカーの色（速度ベース）
    var markerColor: Color {
        return transportMode == .walking ? .blue : .red
    }
    
    enum TransportMode {
        case walking
        case vehicle
        case unknown
    }
    
    // MARK: - Equatable
    // id・座標・タイムスタンプ・測位方式が一致する場合のみ「同じ」とみなす
    // → 座標が同じでも時刻や測位方式が変われば onChange が発火する
    static func == (lhs: BusLocation, rhs: BusLocation) -> Bool {
        return lhs.latitude == rhs.latitude &&
               lhs.longitude == rhs.longitude &&
               lhs.timestamp.seconds == rhs.timestamp.seconds &&
               lhs.locationSource == rhs.locationSource
    }
}


