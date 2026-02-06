//
//  ZoneEvent.swift
//  mimamoriGPS
//
//  セーフゾーン入退場イベントのモデル（Firebase削除版）
//

import Foundation

struct ZoneEvent: Identifiable, Codable {
    var id: String?
    var safeZoneId: String
    var safeZoneName: String
    var childId: String
    var eventType: EventType
    var timestamp: Date
    var location: GeoPoint
    var notificationSent: Bool
    
    enum EventType: String, Codable {
        case enter = "enter"
        case exit = "exit"
    }
    
    // MARK: - Computed Properties
    
    /// イベント日時
    var date: Date {
        timestamp
    }
    
    /// イベントの説明
    var description: String {
        let action = eventType == .enter ? "入場" : "退場"
        return "\(safeZoneName)に\(action)"
    }
    
    /// イベントアイコン
    var icon: String {
        eventType == .enter ? "🏠" : "🚪"
    }
}
