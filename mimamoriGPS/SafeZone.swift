//
//  SafeZone.swift
//  mimamoriGPS
//
//  セーフゾーンのデータモデル（Firebase削除版 - AWS API専用）
//

import Foundation
import CoreLocation

struct SafeZone: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var centerLat: Double
    var centerLon: Double
    var radius: Double
    var enabled: Bool
    var createdAt: Date
    var updatedAt: Date
    var color: String // UIでの表示色（HEX形式）
    
    // MARK: - Computed Properties
    
    /// 中心座標をCLLocationCoordinate2Dで返す
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }
    
    /// Coordinate型で返す（AWS API用）
    var center: Coordinate {
        Coordinate(lat: centerLat, lon: centerLon)
    }
    
    /// 作成日時
    var createdDate: Date {
        createdAt
    }
    
    /// 更新日時
    var updatedDate: Date {
        updatedAt
    }
    
    // MARK: - Initializer
    
    init(
        id: String = UUID().uuidString,
        name: String,
        centerLat: Double,
        centerLon: Double,
        radius: Double,
        enabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        color: String = "#0000FF" // デフォルトは青
    ) {
        self.id = id
        self.name = name
        self.centerLat = centerLat
        self.centerLon = centerLon
        self.radius = radius
        self.enabled = enabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.color = color
    }
    
    /// APISafeZoneから変換
    init(from apiZone: APISafeZone) {
        self.id = apiZone.zoneId
        self.name = apiZone.name
        self.centerLat = apiZone.center.lat
        self.centerLon = apiZone.center.lon
        self.radius = apiZone.radius
        self.enabled = apiZone.enabled
        self.createdAt = apiZone.createdDate ?? Date()
        self.updatedAt = apiZone.updatedDate ?? Date()
        self.color = "#0000FF" // デフォルトの青
    }
    
    /// CLLocationCoordinate2Dから初期化
    init(
        id: String = UUID().uuidString,
        name: String,
        center: CLLocationCoordinate2D,
        radius: Double,
        enabled: Bool = true
    ) {
        self.init(
            id: id,
            name: name,
            centerLat: center.latitude,
            centerLon: center.longitude,
            radius: radius,
            enabled: enabled
        )
    }
    
    // MARK: - Equatable
    
    static func == (lhs: SafeZone, rhs: SafeZone) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.centerLat == rhs.centerLat &&
               lhs.centerLon == rhs.centerLon &&
               lhs.radius == rhs.radius
    }
}

// MARK: - SafeZone Extensions

extension SafeZone {
    /// 指定した座標がセーフゾーン内にあるか判定
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let center = CLLocation(latitude: centerLat, longitude: centerLon)
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = center.distance(from: target)
        return distance <= radius
    }
    
    /// Location型で判定
    func contains(_ location: Location) -> Bool {
        return contains(location.coordinate)
    }
}
