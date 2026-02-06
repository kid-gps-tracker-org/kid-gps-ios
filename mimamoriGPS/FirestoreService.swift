//
//  FirestoreService.swift
//  mimamoriGPS
//
//  AWS REST APIからデバイス位置データを取得（Firebase削除版）
//

import Foundation
import Combine

// MARK: - Firebase置き換え型定義

/// GeoPoint構造体（Firebase不要版）
struct GeoPoint: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Timestamp構造体（Firebase不要版）
struct Timestamp: Codable, Hashable {
    let seconds: Int64
    let nanoseconds: Int32
    
    init(date: Date) {
        self.seconds = Int64(date.timeIntervalSince1970)
        self.nanoseconds = Int32((date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)) * 1_000_000_000)
    }
    
    func dateValue() -> Date {
        return Date(timeIntervalSince1970: Double(seconds) + Double(nanoseconds) / 1_000_000_000)
    }
}

// MARK: - Extensions

extension Double {
    /// 指定した小数点以下桁数で文字列に変換
    func toFixed(_ digits: Int) -> String {
        return String(format: "%.\(digits)f", self)
    }
}

class FirestoreService: ObservableObject {
    // MARK: - Published Properties
    @Published var currentBusLocation: BusLocation?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var locationHistory: [BusLocation] = []
    // MARK: - Safe Zone Properties
    @Published var safeZones: [SafeZone] = []
    @Published var zoneEvents: [ZoneEvent] = []
    
    // MARK: - Private Properties
    private var pollingTimer: Timer?  // ポーリング用タイマー
    private var safeZonePollingTimer: Timer?
    private var zoneEventPollingTimer: Timer?
    
    // MARK: - Singleton
    static let shared = FirestoreService()
    
    // MARK: - Public Methods
    
    /// バス位置のリアルタイム監視を開始（AWS API専用）
    func startListening() {
        isLoading = true
        errorMessage = nil
        
        // 常にAWS APIからポーリング
        startAWSPolling()
    }
    
    /// リアルタイム監視を停止
    func stopListening() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        print("🛑 デバイス位置監視停止")
    }
    
    // MARK: - 履歴取得（AWS API版）
    
    /// 指定した日付の位置履歴を取得(0時〜23時59分59秒)
    func fetchLocationHistory(for date: Date = Date()) {
        let calendar = Calendar.current
        
        // 指定日の0時0分0秒
        let startOfDay = calendar.startOfDay(for: date)
        
        // 指定日の23時59分59秒
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) else {
            print("❌ 日付計算エラー")
            return
        }
        
        // 日付をフォーマットして表示
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        let dateString = formatter.string(from: date)
        
        print("📅 軌跡表示: \(dateString)のデータを取得")
        print("   開始: \(startOfDay)")
        print("   終了: \(endOfDay)")
        
        guard let deviceId = getDeviceId() else {
            print("❌ Device IDが設定されていません")
            locationHistory = []
            return
        }
        
        // AWS APIから履歴データを取得
        Task {
            do {
                let response = try await AWSNetworkService.shared.getHistory(
                    deviceId: deviceId,
                    type: nil,  // 全てのタイプを取得（位置情報と温度）
                    start: startOfDay,
                    end: endOfDay,
                    limit: 1000
                )
                
                // HistoryEntry → BusLocation に変換
                let busLocations = response.history.compactMap { entry -> BusLocation? in
                    // 位置情報のみ（温度データを除外）
                    guard entry.messageType != .temp,
                          let lat = entry.lat,
                          let lon = entry.lon else {
                        return nil
                    }
                    
                    return BusLocation(
                        id: UUID().uuidString,
                        latitude: lat,
                        longitude: lon,
                        timestamp: Timestamp(date: entry.date ?? Date()),
                        speed: nil,
                        azimuth: nil,
                        fromBusstopPole: nil,
                        toBusstopPole: nil,
                        busOperator: "nRF Device",
                        busRoute: deviceId
                    )
                }
                
                await MainActor.run {
                    self.locationHistory = busLocations
                    print("✅ 履歴データ取得: \(busLocations.count)件(\(dateString))")
                }
                
            } catch {
                print("❌ 履歴取得エラー: \(error)")
                await MainActor.run {
                    self.locationHistory = []
                }
            }
        }
    }
    
    // MARK: - AWS REST API Polling
    
    /// AWS REST APIからのポーリングを開始
    private func startAWSPolling() {
        print("🚀 AWS REST API ポーリング開始...")
        
        // 設定確認
        guard AWSNetworkService.shared.isConfigured() else {
            errorMessage = "AWS APIの設定が必要です。設定画面でBase URLとAPI Keyを入力してください。"
            isLoading = false
            return
        }
        
        guard let deviceId = getDeviceId() else {
            errorMessage = "Device IDが設定されていません"
            isLoading = false
            return
        }
        
        // 初回取得
        Task {
            await fetchLocationFromAWS(deviceId: deviceId)
        }
        
        // 60秒ごとにポーリング
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                await self.fetchLocationFromAWS(deviceId: deviceId)
            }
        }
    }
    
    /// AWS REST APIから位置情報を取得
    private func fetchLocationFromAWS(deviceId: String) async {
        do {
            print("🌐 AWS API: 位置情報取得開始 (deviceId: \(deviceId))")
            
            // デバイス情報を取得
            let deviceResponse = try await AWSNetworkService.shared.getDevices()
            
            // 指定されたデバイスを探す
            guard let device = deviceResponse.devices.first(where: { $0.deviceId == deviceId }) else {
                errorMessage = "デバイスが見つかりません"
                isLoading = false
                return
            }
            
            // 位置情報があればBusLocationに変換
            if let location = device.lastLocation {
                let busLocation = BusLocation(
                    id: deviceId,
                    latitude: location.lat,
                    longitude: location.lon,
                    timestamp: Timestamp(date: location.date ?? Date()),
                    speed: nil,  // AWS APIにはspeed情報がない
                    azimuth: nil,  // AWS APIにはazimuth情報がない
                    fromBusstopPole: nil,
                    toBusstopPole: nil,
                    busOperator: "nRF Device",
                    busRoute: deviceId
                )
                
                await MainActor.run {
                    self.currentBusLocation = busLocation
                    self.errorMessage = nil
                    self.isLoading = false
                }
                
                print("✅ AWS API 位置情報取得成功: (\(location.lat), \(location.lon))")
                print("📍 測位方式: \(location.source.rawValue)")
                print("📏 精度: \(location.accuracy) m")
                
                // タイムスタンプを表示
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = TimeZone.current
                if let date = location.date {
                    print("🕐 データの時刻: \(formatter.string(from: date))")
                } else {
                    print("⚠️ タイムスタンプの解析に失敗")
                }
                print("🕐 現在時刻: \(formatter.string(from: Date()))")
            } else {
                await MainActor.run {
                    self.errorMessage = "位置情報がありません"
                    self.isLoading = false
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "AWS API エラー: \(error.localizedDescription)"
                self.isLoading = false
            }
            print("❌ AWS API エラー: \(error)")
        }
    }
    
    /// Device IDを取得（UserDefaultsから）
    private func getDeviceId() -> String? {
        // nRF Cloud設定のDevice IDを使用
        let deviceId = UserDefaults.standard.string(forKey: "nrf_device_id")
        return deviceId?.isEmpty == false ? deviceId : nil
    }
    
    // MARK: - Safe Zone Methods
    
    /// セーフゾーンのリアルタイム監視を開始（AWS API版）
    func startListeningSafeZones(childId: String) {
        print("🚀 セーフゾーン監視開始: childId=\(childId)")
        
        // AWS APIからセーフゾーンを取得
        Task {
            await fetchSafeZonesFromAWS(deviceId: childId)
        }
        
        // 定期的にポーリング（5分ごと）
        safeZonePollingTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchSafeZonesFromAWS(deviceId: childId)
            }
        }
    }
    
    /// セーフゾーン監視を停止
    func stopListeningSafeZones() {
        safeZonePollingTimer?.invalidate()
        safeZonePollingTimer = nil
        print("🛑 セーフゾーン監視停止")
    }
    
    /// AWS APIからセーフゾーンを取得
    private func fetchSafeZonesFromAWS(deviceId: String) async {
        do {
            print("🌐 AWS API: セーフゾーン取得開始 (deviceId: \(deviceId))")
            
            let response = try await AWSNetworkService.shared.getSafeZones(deviceId: deviceId)
            
            // APISafeZone から SafeZone に変換
            let convertedZones = response.safezones.compactMap { apiZone -> SafeZone? in
                convertAPISafeZoneToSafeZone(apiZone, deviceId: deviceId)
            }
            
            await MainActor.run {
                self.safeZones = convertedZones
            }
            
            print("✅ AWS API セーフゾーン取得成功: \(convertedZones.count)件")
            for zone in convertedZones {
                print("  - \(zone.name): (\(zone.centerLat), \(zone.centerLon)), 半径:\(zone.radius)m")
            }
            
        } catch {
            print("❌ AWS API セーフゾーン取得エラー: \(error)")
        }
    }
    
    /// APISafeZone を SafeZone に変換
    private func convertAPISafeZoneToSafeZone(_ apiZone: APISafeZone, deviceId: String) -> SafeZone? {
        return SafeZone(
            id: apiZone.zoneId,
            name: apiZone.name,
            centerLat: apiZone.center.lat,
            centerLon: apiZone.center.lon,
            radius: apiZone.radius,
            enabled: apiZone.enabled,
            color: "#0000FF"  // デフォルトの青色
        )
    }
    
    /// SafeZone を SafeZoneRequest に変換
    /// - Parameter zone: 変換するSafeZone
    /// - Parameter isNewZone: 新規作成の場合はtrue（zoneIdをnilにする）
    private func convertSafeZoneToAPIRequest(_ zone: SafeZone, isNewZone: Bool = false) -> SafeZoneRequest {
        return SafeZoneRequest(
            zoneId: isNewZone ? nil : zone.id,  // 新規作成時はnilを設定
            name: zone.name,
            center: Coordinate(lat: zone.centerLat, lon: zone.centerLon),
            radius: zone.radius,
            enabled: zone.enabled
        )
    }
    
    /// セーフゾーンを追加（AWS API版）
    func addSafeZone(_ zone: SafeZone, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                guard let deviceId = getDeviceId() else {
                    throw NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device ID is missing"])
                }
                
                let request = convertSafeZoneToAPIRequest(zone, isNewZone: true)  // 新規作成フラグをtrueに
                _ = try await AWSNetworkService.shared.putSafeZone(deviceId: deviceId, request: request)
                
                // 再取得
                await fetchSafeZonesFromAWS(deviceId: deviceId)
                
                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// セーフゾーンを更新（AWS API版）
    func updateSafeZone(_ zone: SafeZone, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                guard let deviceId = getDeviceId() else {
                    throw NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device ID is missing"])
                }
                
                let request = convertSafeZoneToAPIRequest(zone, isNewZone: false)  // 更新なのでfalse
                _ = try await AWSNetworkService.shared.putSafeZone(deviceId: deviceId, request: request)
                
                // 再取得
                await fetchSafeZonesFromAWS(deviceId: deviceId)
                
                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// セーフゾーンを削除（AWS API版）
    func deleteSafeZone(_ zoneId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                guard let deviceId = getDeviceId() else {
                    throw NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Device ID is missing"])
                }
                
                _ = try await AWSNetworkService.shared.deleteSafeZone(deviceId: deviceId, zoneId: zoneId)
                
                // 再取得
                await fetchSafeZonesFromAWS(deviceId: deviceId)
                
                await MainActor.run {
                    completion(.success(()))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Zone Event Methods (AWS未実装のため一旦空実装)
    
    /// 入退場イベントのリアルタイム監視を開始（AWS API実装待ち）
    func startListeningZoneEvents(childId: String, limit: Int = 100) {
        print("🚀 ZoneEventListView.task 開始: childId=\(childId)")
        print("⚠️ AWS APIでのZoneEvent実装待ち")
        // TODO: AWS APIでZoneEventエンドポイントが実装されたら対応
    }
    
    /// 入退場イベント監視を停止
    func stopListeningZoneEvents() {
        zoneEventPollingTimer?.invalidate()
        zoneEventPollingTimer = nil
        print("🛑 入退場イベント監視停止")
    }
    
    // MARK: - APNs Token Methods (Firebase削除版)
        
    /// APNsトークンを保存（UserDefaultsのみ、AWS連携は今後実装）
    func saveFCMToken(_ token: String, forUserId userId: String) {
        // UserDefaultsに保存
        UserDefaults.standard.set(token, forKey: "apns_device_token")
        print("✅ APNsトークン保存: \(token)")
        
        // TODO: AWS SNS連携（今後実装）
    }
}
