//
//  APIModels.swift
//  mimamoriGPS
//
//  AWS REST API用のデータモデル
//  API仕様書 v1.0 に準拠
//

import Foundation
import CoreLocation

// MARK: - 3.1 Location 型

struct Location: Codable, Equatable {
    let lat: Double
    let lon: Double
    let accuracy: Double
    let source: LocationSource
    let timestamp: String  // ISO 8601
    
    enum LocationSource: String, Codable {
        case gnss      = "GNSS"
        case groundFix = "GROUND_FIX"
    }

    // MARK: - カスタムデコード
    // source フィールドに未知の値が来てもデコードエラーにしない

    enum CodingKeys: String, CodingKey {
        case lat, lon, accuracy, source, timestamp
    }

    init(lat: Double, lon: Double, accuracy: Double, source: LocationSource, timestamp: String) {
        self.lat = lat
        self.lon = lon
        self.accuracy = accuracy
        self.source = source
        self.timestamp = timestamp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lat       = try c.decode(Double.self, forKey: .lat)
        lon       = try c.decode(Double.self, forKey: .lon)
        accuracy  = try c.decode(Double.self, forKey: .accuracy)
        timestamp = try c.decode(String.self, forKey: .timestamp)

        // source が未知の値でも "GNSS" フォールバックしてデコードを継続
        let rawSource = try c.decode(String.self, forKey: .source)
        if let parsed = LocationSource(rawValue: rawSource) {
            source = parsed
        } else {
            print("⚠️ Location.source 未知の値: '\(rawSource)' → .gnss にフォールバック")
            source = .gnss
        }
    }
    
    /// CLLocationCoordinate2Dに変換
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// タイムスタンプをDateに変換
    var date: Date? {
        return ISO8601DateFormatter.withFractionalSeconds.date(from: timestamp)
    }
}

// MARK: - 3.2 Temperature 型

struct Temperature: Codable, Equatable {
    let value: Double  // ℃
    let timestamp: String  // ISO 8601
    
    /// タイムスタンプをDateに変換
    var date: Date? {
        return ISO8601DateFormatter.withFractionalSeconds.date(from: timestamp)
    }
}

// MARK: - 3.3 Coordinate 型

struct Coordinate: Codable, Equatable {
    let lat: Double
    let lon: Double
    
    /// CLLocationCoordinate2Dから初期化
    init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
    
    /// CLLocationCoordinate2Dから初期化
    init(_ coordinate: CLLocationCoordinate2D) {
        self.lat = coordinate.latitude
        self.lon = coordinate.longitude
    }
    
    /// CLLocationCoordinate2Dに変換
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - 3.4 SafeZone 型 (API用)

struct APISafeZone: Codable, Equatable {
    let zoneId: String  // UUID
    let name: String
    let center: Coordinate
    let radius: Double  // メートル
    let enabled: Bool
    let createdAt: String  // ISO 8601
    let updatedAt: String  // ISO 8601
    
    /// 作成日時をDateに変換
    var createdDate: Date? {
        return ISO8601DateFormatter.withFractionalSeconds.date(from: createdAt)
    }
    
    /// 更新日時をDateに変換
    var updatedDate: Date? {
        return ISO8601DateFormatter.withFractionalSeconds.date(from: updatedAt)
    }
}

// MARK: - 3.5 Device 型

struct Device: Codable, Equatable {
    let deviceId: String  // nrf-{IMEI 15桁}
    let lastLocation: Location?
    let lastTemperature: Temperature?
    let inSafeZone: Bool
    let firmwareVersion: String?
    let lastSeen: String?  // ISO 8601
    
    /// 最終接続日時をDateに変換
    var lastSeenDate: Date? {
        guard let lastSeen = lastSeen else { return nil }
        return ISO8601DateFormatter.withFractionalSeconds.date(from: lastSeen)
    }
}

// MARK: - 3.6 HistoryEntry 型

struct HistoryEntry: Codable, Equatable {
    let timestamp: String  // ISO 8601
    let messageType: MessageType
    let lat: Double?
    let lon: Double?
    let accuracy: Double?
    let temperature: Double?
    let zoneId: String?    // ZONE_ENTER / ZONE_EXIT のみ値あり
    let zoneName: String?  // ZONE_ENTER / ZONE_EXIT のみ値あり
    
    enum MessageType: String, Codable {
        case gnss = "GNSS"
        case groundFix = "GROUND_FIX"
        case temp = "TEMP"
        case zoneEnter = "ZONE_ENTER"
        case zoneExit = "ZONE_EXIT"
        case unknown  // 未知の値をデコードエラーにしないためのフォールバック

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            self = MessageType(rawValue: raw) ?? .unknown
        }
    }
    
    /// タイムスタンプをDateに変換
    var date: Date? {
        return ISO8601DateFormatter.withFractionalSeconds.date(from: timestamp)
    }
    
    /// 位置情報がある場合、CLLocationCoordinate2Dに変換
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lon = lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - 3.7 FirmwareInfo 型

struct FirmwareInfo: Codable, Equatable {
    let currentVersion: String
    let lastUpdated: String?  // ISO 8601
    
    /// 更新日時をDateに変換
    var lastUpdatedDate: Date? {
        guard let lastUpdated = lastUpdated else { return nil }
        return ISO8601DateFormatter.withFractionalSeconds.date(from: lastUpdated)
    }
}

// MARK: - 3.8 FotaJob 型

struct FotaJob: Codable, Equatable {
    let jobId: String
    let status: JobStatus
    let firmwareId: String
    let createdAt: String  // ISO 8601
    let completedAt: String?  // ISO 8601
    
    enum JobStatus: String, Codable {
        case queued = "QUEUED"
        case inProgress = "IN_PROGRESS"
        case succeeded = "SUCCEEDED"
        case failed = "FAILED"
        case timedOut = "TIMED_OUT"
    }
    
    /// 作成日時をDateに変換
    var createdDate: Date? {
        return ISO8601DateFormatter.withFractionalSeconds.date(from: createdAt)
    }
    
    /// 完了日時をDateに変換
    var completedDate: Date? {
        guard let completedAt = completedAt else { return nil }
        return ISO8601DateFormatter.withFractionalSeconds.date(from: completedAt)
    }
}

// MARK: - 3.9 ApiError 型

struct ApiError: Codable, Equatable {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable, Equatable {
        let code: String  // SCREAMING_SNAKE_CASE
        let message: String
    }
}

// MARK: - API レスポンス型

// 4.1 GET /devices
struct DevicesResponse: Codable {
    let devices: [Device]
}

// 4.2 GET /devices/{deviceId}/location
struct LocationResponse: Codable {
    let deviceId: String
    let location: Location
}

// 4.3 GET /devices/{deviceId}/temperature
struct TemperatureResponse: Codable {
    let deviceId: String
    let temperature: Temperature
}

// 4.4 GET /devices/{deviceId}/history
struct HistoryResponse: Codable {
    let deviceId: String
    let history: [HistoryEntry]
    let count: Int
}

// 4.5 GET /devices/{deviceId}/safezones
struct SafeZonesResponse: Codable {
    let deviceId: String
    let safezones: [APISafeZone]
}

// 4.6 PUT /devices/{deviceId}/safezones
struct SafeZoneRequest: Codable {
    let zoneId: String?  // 省略時は新規作成
    let name: String?
    let center: Coordinate?
    let radius: Double?
    let enabled: Bool?
}

struct SafeZoneResponse: Codable {
    let deviceId: String
    let safezone: APISafeZone
}

// 4.7 DELETE /devices/{deviceId}/safezones/{zoneId}
struct DeleteResponse: Codable {
    let deleted: Bool
    let zoneId: String
}

// 4.8 GET /devices/{deviceId}/firmware
struct FirmwareResponse: Codable {
    let deviceId: String
    let firmware: FirmwareInfo
}

// 4.9 POST /devices/{deviceId}/firmware/update
struct FirmwareUpdateRequest: Codable {
    let firmwareId: String
}

struct FirmwareUpdateResponse: Codable {
    let deviceId: String
    let fota: FotaJob
}

// 4.10 GET /devices/{deviceId}/firmware/status
struct FirmwareStatusResponse: Codable {
    let deviceId: String
    let fota: FotaJob
}

// MARK: - プッシュ通知ペイロード (6.1, 6.2)

struct PushNotificationData: Codable {
    let type: NotificationType
    let deviceId: String
    let zoneId: String
    let zoneName: String
    let location: Location
    let detectedAt: String  // ISO 8601
    
    enum NotificationType: String, Codable {
        case zoneExit = "ZONE_EXIT"
        case zoneEnter = "ZONE_ENTER"
    }
    
    /// 検出日時をDateに変換
    var detectedDate: Date? {
        return ISO8601DateFormatter.withFractionalSeconds.date(from: detectedAt)
    }
}

// MARK: - ISO8601DateFormatter Extension

extension ISO8601DateFormatter {
    /// ミリ秒付きのISO8601DateFormatter（仕様書準拠）
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /// 標準のISO8601DateFormatter（ミリ秒なし）
    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

// MARK: - Date Extension

extension Date {
    /// ISO 8601形式の文字列に変換（ミリ秒付き）
    func toISO8601String() -> String {
        return ISO8601DateFormatter.withFractionalSeconds.string(from: self)
    }
}
