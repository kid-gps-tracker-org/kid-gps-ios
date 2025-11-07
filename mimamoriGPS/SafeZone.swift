//
//  SafeZone.swift
//  mimamoriGPS
//
//  セーフゾーンのデータモデル
//

import Foundation
import FirebaseFirestore
import CoreLocation

struct SafeZone: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var center: GeoPoint
    var radius: Double
    var childId: String
    var createdBy: String
    var color: String
    var icon: String?
    var isActive: Bool
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?
    
    // MARK: - Computed Properties
    
    /// 中心座標をCLLocationCoordinate2Dで返す
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: center.latitude,
            longitude: center.longitude
        )
    }
    
    /// UIColorに変換
    var uiColor: UIColor {
        UIColor(hex: color) ?? .systemBlue
    }
    
    /// 作成日時
    var createdDate: Date? {
        createdAt?.dateValue()
    }
    
    /// 更新日時
    var updatedDate: Date? {
        updatedAt?.dateValue()
    }
    
    // MARK: - Initializer
    
    init(
        id: String? = nil,
        name: String,
        center: GeoPoint,
        radius: Double,
        childId: String,
        createdBy: String,
        color: String = "#0000FF",
        icon: String? = "home",
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.center = center
        self.radius = radius
        self.childId = childId
        self.createdBy = createdBy
        self.color = color
        self.icon = icon
        self.isActive = isActive
    }
    
    // MARK: - Equatable
    
    static func == (lhs: SafeZone, rhs: SafeZone) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.radius == rhs.radius
    }
}

// MARK: - GeoPoint Extension

extension GeoPoint {
    /// CLLocationCoordinate2Dから初期化
    convenience init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

// MARK: - UIColor Extension

extension UIColor {
    /// HEX文字列からUIColorを生成
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    /// UIColorをHEX文字列に変換
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }
}
