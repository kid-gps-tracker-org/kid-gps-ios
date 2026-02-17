//
//  AWSNetworkService.swift
//  mimamoriGPS
//
//  AWS REST API との通信を担当するサービス
//  API仕様書 v1.0 に準拠
//

import Foundation

class AWSNetworkService {
    // MARK: - Singleton
    static let shared = AWSNetworkService()
    
    private init() {}
    
    // MARK: - Configuration
    
    /// ベースURL
    private var baseURL: String {
        // 設定から取得、または環境変数から取得
        if let url = UserDefaults.standard.string(forKey: "aws_base_url"), !url.isEmpty {
            return url
        }
        // デフォルト値（開発環境）
        return "https://{api-id}.execute-api.ap-northeast-1.amazonaws.com/dev"
    }
    
    /// API Key
    private var apiKey: String {
        if let key = UserDefaults.standard.string(forKey: "aws_api_key"), !key.isEmpty {
            return key
        }
        return ""
    }
    
    /// 設定が完了しているか確認
    func isConfigured() -> Bool {
        return !apiKey.isEmpty && !baseURL.contains("{api-id}")
    }
    
    // MARK: - HTTP Request Helper
    
    private func createRequest(
        path: String,
        method: String,
        body: Data? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    private func performRequest<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        print("📡 AWS API Response: \(httpResponse.statusCode)")
        print("📄 Response Body: \(String(data: data, encoding: .utf8) ?? "n/a")")
        
        // エラーレスポンスの処理
        if httpResponse.statusCode >= 400 {
            if let apiError = try? JSONDecoder().decode(ApiError.self, from: data) {
                throw NetworkError.apiError(apiError)
            }
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        // 成功レスポンスのデコード
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            // デコードエラーの詳細をログ出力
            switch decodingError {
            case .typeMismatch(let type, let context):
                print("❌ DecodingError.typeMismatch: type=\(type), path=\(context.codingPath.map(\.stringValue).joined(separator: ".")), \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("❌ DecodingError.valueNotFound: type=\(type), path=\(context.codingPath.map(\.stringValue).joined(separator: ".")), \(context.debugDescription)")
            case .keyNotFound(let key, let context):
                print("❌ DecodingError.keyNotFound: key=\(key.stringValue), path=\(context.codingPath.map(\.stringValue).joined(separator: ".")), \(context.debugDescription)")
            case .dataCorrupted(let context):
                print("❌ DecodingError.dataCorrupted: path=\(context.codingPath.map(\.stringValue).joined(separator: ".")), \(context.debugDescription)")
            @unknown default:
                print("❌ DecodingError.unknown: \(decodingError)")
            }
            print("📄 Raw JSON:\n\(String(data: data, encoding: .utf8) ?? "n/a")")
            throw decodingError
        }
    }
    
    // MARK: - 4.1 GET /devices
    
    /// デバイス一覧取得
    func getDevices() async throws -> DevicesResponse {
        let request = try createRequest(path: "/devices", method: "GET")
        print("🌐 GET /devices")
        return try await performRequest(request: request)
    }
    
    // MARK: - 4.2 GET /devices/{deviceId}/location
    
    /// 最新位置情報取得
    func getLocation(deviceId: String) async throws -> LocationResponse {
        let request = try createRequest(path: "/devices/\(deviceId)/location", method: "GET")
        print("🌐 GET /devices/\(deviceId)/location")
        return try await performRequest(request: request)
    }
    
    // MARK: - 4.3 GET /devices/{deviceId}/temperature
    
    /// 最新温度情報取得
    func getTemperature(deviceId: String) async throws -> TemperatureResponse {
        let request = try createRequest(path: "/devices/\(deviceId)/temperature", method: "GET")
        print("🌐 GET /devices/\(deviceId)/temperature")
        return try await performRequest(request: request)
    }
    
    // MARK: - 4.4 GET /devices/{deviceId}/history
    
    /// 履歴取得
    func getHistory(
        deviceId: String,
        type: HistoryEntry.MessageType? = nil,
        start: Date? = nil,
        end: Date? = nil,
        limit: Int? = nil
    ) async throws -> HistoryResponse {
        var path = "/devices/\(deviceId)/history"
        var queryItems: [String] = []
        
        if let type = type {
            queryItems.append("type=\(type.rawValue)")
        }
        if let start = start {
            queryItems.append("start=\(start.toISO8601String())")
        }
        if let end = end {
            queryItems.append("end=\(end.toISO8601String())")
        }
        if let limit = limit {
            queryItems.append("limit=\(limit)")
        }
        
        if !queryItems.isEmpty {
            path += "?" + queryItems.joined(separator: "&")
        }
        
        let request = try createRequest(path: path, method: "GET")
        print("🌐 GET \(path)")
        return try await performRequest(request: request)
    }
    
    // MARK: - 4.5 GET /devices/{deviceId}/safezones
    
    /// セーフゾーン一覧取得
    func getSafeZones(deviceId: String) async throws -> SafeZonesResponse {
        let request = try createRequest(path: "/devices/\(deviceId)/safezones", method: "GET")
        print("🌐 GET /devices/\(deviceId)/safezones")
        return try await performRequest(request: request)
    }
    
    // MARK: - 4.6 PUT /devices/{deviceId}/safezones
    
    /// セーフゾーン作成・更新
    func putSafeZone(
        deviceId: String,
        request safeZoneRequest: SafeZoneRequest
    ) async throws -> SafeZoneResponse {
        let encoder = JSONEncoder()
        let body = try encoder.encode(safeZoneRequest)
        
        let request = try createRequest(
            path: "/devices/\(deviceId)/safezones",
            method: "PUT",
            body: body
        )
        
        print("🌐 PUT /devices/\(deviceId)/safezones")
        print("📤 Request Body: \(String(data: body, encoding: .utf8) ?? "n/a")")
        
        return try await performRequest(request: request)
    }
    
    // MARK: - 4.7 DELETE /devices/{deviceId}/safezones/{zoneId}
    
    /// セーフゾーン削除
    func deleteSafeZone(deviceId: String, zoneId: String) async throws -> DeleteResponse {
        let request = try createRequest(
            path: "/devices/\(deviceId)/safezones/\(zoneId)",
            method: "DELETE"
        )
        
        print("🌐 DELETE /devices/\(deviceId)/safezones/\(zoneId)")
        return try await performRequest(request: request)
    }
    
    // MARK: - 4.8 GET /devices/{deviceId}/firmware
    
    /// ファームウェア情報取得
    func getFirmware(deviceId: String) async throws -> FirmwareResponse {
        let request = try createRequest(path: "/devices/\(deviceId)/firmware", method: "GET")
        print("🌐 GET /devices/\(deviceId)/firmware")
        return try await performRequest(request: request)
    }
    
    // MARK: - 4.9 POST /devices/{deviceId}/firmware/update
    
    /// ファームウェア更新ジョブ作成
    func updateFirmware(
        deviceId: String,
        firmwareId: String
    ) async throws -> FirmwareUpdateResponse {
        let encoder = JSONEncoder()
        let requestBody = FirmwareUpdateRequest(firmwareId: firmwareId)
        let body = try encoder.encode(requestBody)
        
        let request = try createRequest(
            path: "/devices/\(deviceId)/firmware/update",
            method: "POST",
            body: body
        )
        
        print("🌐 POST /devices/\(deviceId)/firmware/update")
        return try await performRequest(request: request)
    }
    
    // MARK: - 4.10 GET /devices/{deviceId}/firmware/status
    
    /// FOTA ジョブステータス取得
    func getFirmwareStatus(deviceId: String) async throws -> FirmwareStatusResponse {
        let request = try createRequest(
            path: "/devices/\(deviceId)/firmware/status",
            method: "GET"
        )
        
        print("🌐 GET /devices/\(deviceId)/firmware/status")
        return try await performRequest(request: request)
    }
}

// MARK: - Network Error

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(ApiError)
    case notConfigured
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "無効なURLです"
        case .invalidResponse:
            return "サーバーからの応答が無効です"
        case .httpError(let code):
            return "HTTPエラー: \(code)"
        case .apiError(let apiError):
            return "APIエラー [\(apiError.error.code)]: \(apiError.error.message)"
        case .notConfigured:
            return "AWS APIの設定が完了していません"
        }
    }
}
