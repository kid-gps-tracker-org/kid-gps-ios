//
//  APIModels.swift
//  mimamoriGPS
//
//  AWS REST API データモデル
//  API仕様書 v1.0 準拠
//

import Foundation

// MARK: - 2. 共通データ型

/// 2.1 Location - 位置情報
struct Location: Codable {
    let lat: Double
    let lon: Double
    let accuracy: Double
    let source: LocationSource
    let timestamp: String
    
    enum LocationSource: String, Codable {
        case GNSS
        case GROUND_FIX
    }
    
    /// タイムスタンプをDateに変換
    var date: Date? {
        ISO8601DateFormatter.withFractionalSeconds.date(from: timestamp)
    }
}

/// 2.2 Temperature - 温度情報
struct Temperature: Codable {
    let value: Double
    let timestamp: String
    
    /// タイムスタンプをDateに変換
    var date: Date? {
        ISO8601DateFormatter.withFractionalSeconds.date(from: timestamp)
    }
}

/// 2.3 Coordinate - 座標
struct Coordinate: Codable {
    let lat: Double
    let lon: Double
}

// MARK: - 3. エンドポイント定義

/// 3.1 GET /devices - デバイス一覧レスポンス
struct DevicesResponse: Codable {
    let devices: [Device]
}

/// Device - デバイス情報
struct Device: Codable {
    let deviceId: String
    let lastLocation: Location?
    let lastTemperature: Temperature?
}

/// 3.2 GET /devices/{deviceId}/location - 位置情報レスポンス
struct LocationResponse: Codable {
    let location: Location
}

/// 3.3 GET /devices/{deviceId}/temperature - 温度情報レスポンス
struct TemperatureResponse: Codable {
    let temperature: Temperature
}

/// 3.4 GET /devices/{deviceId}/history - 履歴レスポンス
struct HistoryResponse: Codable {
    let history: [HistoryEntry]
    let count: Int
}

/// HistoryEntry - 履歴エントリ
struct HistoryEntry: Codable {
    let messageType: MessageType
    let timestamp: String
    let data: [String: Any]
    
    enum MessageType: String, Codable {
        case GNSS
        case GROUND_FIX = "GROUND_FIX"
        case temp = "TEMP"
    }
    
    /// タイムスタンプをDateに変換
    var date: Date? {
        ISO8601DateFormatter.withFractionalSeconds.date(from: timestamp)
    }
    
    /// 位置情報を抽出
    var lat: Double? {
        data["lat"] as? Double
    }
    
    var lon: Double? {
        data["lon"] as? Double
    }
    
    var accuracy: Double? {
        data["accuracy"] as? Double
    }
    
    /// 温度情報を抽出
    var temperature: Double? {
        data["value"] as? Double
    }
    
    // カスタムCodable実装（dataフィールドのため）
    enum CodingKeys: String, CodingKey {
        case messageType, timestamp, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageType = try container.decode(MessageType.self, forKey: .messageType)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        
        // dataフィールドを辞書として取得
        if let dataDict = try? container.decode([String: AnyCodable].self, forKey: .data) {
            data = dataDict.mapValues { $0.value }
        } else {
            data = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageType, for: .messageType)
        try container.encode(timestamp, forKey: .timestamp)
        let anyCodableData = data.mapValues { AnyCodable($0) }
        try container.encode(anyCodableData, forKey: .data)
    }
}

/// 3.5 GET /devices/{deviceId}/safezones - セーフゾーン一覧レスポンス
struct SafeZonesResponse: Codable {
    let safezones: [APISafeZone]
}

/// APISafeZone - セーフゾーン
struct APISafeZone: Codable, Identifiable {
    let zoneId: String
    let name: String
    let center: Coordinate
    let radius: Double
    let enabled: Bool
    
    var id: String { zoneId }
}

/// 3.6 PUT /devices/{deviceId}/safezones - セーフゾーン作成/更新リクエスト
struct SafeZoneRequest: Codable {
    let zoneId: String?
    let name: String?
    let center: Coordinate?
    let radius: Double?
    let enabled: Bool?
}

/// 3.6 PUT /devices/{deviceId}/safezones - セーフゾーン作成/更新レスポンス
struct SafeZoneResponse: Codable {
    let safezone: APISafeZone
}

/// 3.7 DELETE /devices/{deviceId}/safezones/{zoneId} - セーフゾーン削除レスポンス
struct DeleteSafeZoneResponse: Codable {
    let message: String
}

/// 3.8 GET /devices/{deviceId}/firmware - ファームウェア情報レスポンス
struct FirmwareResponse: Codable {
    let firmware: FirmwareInfo
}

/// FirmwareInfo - ファームウェア情報
struct FirmwareInfo: Codable {
    let current: String
    let available: String?
    let updateAvailable: Bool
}

/// 3.9 POST /devices/{deviceId}/firmware/update - ファームウェア更新リクエスト
struct FirmwareUpdateRequest: Codable {
    let firmwareId: String
}

/// 3.9 POST /devices/{deviceId}/firmware/update - ファームウェア更新レスポンス
struct FirmwareUpdateResponse: Codable {
    let fota: FotaJob
}

/// FotaJob - FOTA ジョブ
struct FotaJob: Codable {
    let jobId: String
    let status: FotaStatus
    
    enum FotaStatus: String, Codable {
        case IN_PROGRESS
        case COMPLETED
        case FAILED
    }
}

/// 3.10 GET /devices/{deviceId}/firmware/status - FOTA ジョブステータスレスポンス
struct FirmwareStatusResponse: Codable {
    let fota: FotaJob
}

// MARK: - 5. エラーレスポンス

/// ApiError - エラーレスポンス
struct ApiError: Codable, LocalizedError {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let code: String
        let message: String
    }
    
    var errorDescription: String? {
        "[\(error.code)] \(error.message)"
    }
}

// MARK: - 6. プッシュ通知

/// 6.1 / 6.2 プッシュ通知データ
struct PushNotificationData {
    let type: NotificationType
    let deviceId: String
    let zoneId: String
    let zoneName: String
    let location: Location
    let detectedAt: String
    
    enum NotificationType: String {
        case ZONE_ENTER
        case ZONE_EXIT
    }
}

// MARK: - Helper Types

/// AnyCodable - 任意の型をCodableにする
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - ISO8601 Formatter Extension

extension ISO8601DateFormatter {
    /// ミリ秒対応のフォーマッター
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
