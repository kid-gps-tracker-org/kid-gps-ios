//
//  DataService.swift
//  mimamoriGPS
//
//  AWS REST API専用データサービス（Firebase完全削除版）
//

import Foundation
import Combine

class DataService: ObservableObject {
    // MARK: - Published Properties
    @Published var currentLocation: Location?
    @Published var currentTemperature: Temperature?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var locationHistory: [HistoryEntry] = []
    @Published var safeZones: [APISafeZone] = []
    @Published var device: Device?
    
    // MARK: - Private Properties
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval = 60.0  // 60秒ごと
    
    // MARK: - Singleton
    static let shared = DataService()
    
    private init() {}
    
    // MARK: - Device ID管理
    
    var deviceId: String? {
        get {
            UserDefaults.standard.string(forKey: "nrf_device_id")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "nrf_device_id")
        }
    }
    
    // MARK: - リアルタイム監視
    
    /// 位置情報のリアルタイム監視を開始
    func startListening() {
        guard AWSNetworkService.shared.isConfigured() else {
            errorMessage = "AWS APIの設定が必要です"
            isLoading = false
            return
        }
        
        guard let deviceId = deviceId, !deviceId.isEmpty else {
            errorMessage = "Device IDが設定されていません"
            isLoading = false
            return
        }
        
        print("🚀 AWS APIからのデータ取得開始")
        isLoading = true
        errorMessage = nil
        
        // 初回取得
        Task {
            await fetchCurrentData()
        }
        
        // 定期的にポーリング
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchCurrentData()
            }
        }
    }
    
    /// 監視を停止
    func stopListening() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        print("🛑 データ取得停止")
    }
    
    // MARK: - データ取得
    
    /// 現在のデバイスデータを取得
    private func fetchCurrentData() async {
        guard let deviceId = deviceId else { return }
        
        do {
            print("🌐 AWS API: デバイスデータ取得中...")
            
            // デバイス一覧から該当デバイスを取得
            let devicesResponse = try await AWSNetworkService.shared.getDevices()
            guard let device = devicesResponse.devices.first(where: { $0.deviceId == deviceId }) else {
                await MainActor.run {
                    self.errorMessage = "デバイスが見つかりません"
                    self.isLoading = false
                }
                return
            }
            
            await MainActor.run {
                self.device = device
                self.currentLocation = device.lastLocation
                self.currentTemperature = device.lastTemperature
                self.errorMessage = nil
                self.isLoading = false
                
                if let location = device.lastLocation {
                    print("✅ 位置情報取得成功: (\(location.lat), \(location.lon))")
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "データ取得エラー: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("❌ AWS API エラー: \(error)")
        }
    }
    
    /// 履歴データを取得
    func fetchHistory(
        type: HistoryEntry.MessageType? = nil,
        start: Date? = nil,
        end: Date? = nil,
        limit: Int = 100
    ) async {
        guard let deviceId = deviceId else {
            errorMessage = "Device IDが設定されていません"
            return
        }
        
        do {
            print("🌐 AWS API: 履歴データ取得中...")
            
            let response = try await AWSNetworkService.shared.getHistory(
                deviceId: deviceId,
                type: type,
                start: start,
                end: end,
                limit: limit
            )
            
            await MainActor.run {
                self.locationHistory = response.history
                print("✅ 履歴取得成功: \(response.count)件")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "履歴取得エラー: \(error.localizedDescription)"
            }
            print("❌ 履歴取得エラー: \(error)")
        }
    }
    
    // MARK: - セーフゾーン管理
    
    /// セーフゾーン一覧を取得
    func fetchSafeZones() async {
        guard let deviceId = deviceId else {
            errorMessage = "Device IDが設定されていません"
            return
        }
        
        do {
            print("🌐 AWS API: セーフゾーン取得中...")
            
            let response = try await AWSNetworkService.shared.getSafeZones(deviceId: deviceId)
            
            await MainActor.run {
                self.safeZones = response.safezones
                print("✅ セーフゾーン取得成功: \(response.safezones.count)件")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "セーフゾーン取得エラー: \(error.localizedDescription)"
            }
            print("❌ セーフゾーン取得エラー: \(error)")
        }
    }
    
    /// セーフゾーンを作成
    func createSafeZone(name: String, center: Coordinate, radius: Double, enabled: Bool = true) async throws {
        guard let deviceId = deviceId else {
            throw NSError(domain: "DataService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device IDが設定されていません"])
        }
        
        let request = SafeZoneRequest(
            zoneId: nil,  // 新規作成
            name: name,
            center: center,
            radius: radius,
            enabled: enabled
        )
        
        print("🌐 AWS API: セーフゾーン作成中...")
        _ = try await AWSNetworkService.shared.putSafeZone(deviceId: deviceId, request: request)
        
        // 再取得
        await fetchSafeZones()
        print("✅ セーフゾーン作成成功")
    }
    
    /// セーフゾーンを更新
    func updateSafeZone(zoneId: String, name: String?, center: Coordinate?, radius: Double?, enabled: Bool?) async throws {
        guard let deviceId = deviceId else {
            throw NSError(domain: "DataService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device IDが設定されていません"])
        }
        
        let request = SafeZoneRequest(
            zoneId: zoneId,
            name: name,
            center: center,
            radius: radius,
            enabled: enabled
        )
        
        print("🌐 AWS API: セーフゾーン更新中...")
        _ = try await AWSNetworkService.shared.putSafeZone(deviceId: deviceId, request: request)
        
        // 再取得
        await fetchSafeZones()
        print("✅ セーフゾーン更新成功")
    }
    
    /// セーフゾーンを削除
    func deleteSafeZone(zoneId: String) async throws {
        guard let deviceId = deviceId else {
            throw NSError(domain: "DataService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device IDが設定されていません"])
        }
        
        print("🌐 AWS API: セーフゾーン削除中...")
        _ = try await AWSNetworkService.shared.deleteSafeZone(deviceId: deviceId, zoneId: zoneId)
        
        // 再取得
        await fetchSafeZones()
        print("✅ セーフゾーン削除成功")
    }
    
    // MARK: - ファームウェア管理
    
    /// ファームウェア情報を取得
    func fetchFirmwareInfo() async throws -> FirmwareInfo {
        guard let deviceId = deviceId else {
            throw NSError(domain: "DataService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device IDが設定されていません"])
        }
        
        print("🌐 AWS API: ファームウェア情報取得中...")
        let response = try await AWSNetworkService.shared.getFirmware(deviceId: deviceId)
        print("✅ ファームウェア情報取得成功")
        return response.firmware
    }
    
    /// ファームウェア更新を開始
    func updateFirmware(firmwareId: String) async throws -> FotaJob {
        guard let deviceId = deviceId else {
            throw NSError(domain: "DataService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device IDが設定されていません"])
        }
        
        print("🌐 AWS API: ファームウェア更新開始...")
        let response = try await AWSNetworkService.shared.updateFirmware(deviceId: deviceId, firmwareId: firmwareId)
        print("✅ ファームウェア更新ジョブ作成成功")
        return response.fota
    }
    
    /// FOTAジョブステータスを取得
    func fetchFirmwareStatus() async throws -> FotaJob {
        guard let deviceId = deviceId else {
            throw NSError(domain: "DataService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device IDが設定されていません"])
        }
        
        print("🌐 AWS API: FOTAジョブステータス取得中...")
        let response = try await AWSNetworkService.shared.getFirmwareStatus(deviceId: deviceId)
        print("✅ FOTAジョブステータス取得成功")
        return response.fota
    }
}
