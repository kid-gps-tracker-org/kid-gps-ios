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
    
    // MARK: - Computed Properties
    
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
    
    static func == (lhs: BusLocation, rhs: BusLocation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.latitude == rhs.latitude &&
               lhs.longitude == rhs.longitude
    }
}


