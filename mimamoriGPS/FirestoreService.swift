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

@MainActor
class FirestoreService: ObservableObject {
    // MARK: - Published Properties
    @Published var currentBusLocation: BusLocation?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var locationHistory: [BusLocation] = []
    @Published var lastTemperature: Temperature?
    // MARK: - Safe Zone Properties
    @Published var safeZones: [SafeZone] = []
    @Published var zoneEvents: [ZoneEvent] = []
    
    // MARK: - Private Properties
    private var pollingTask: Task<Void, Never>?   // 位置情報ポーリング
    private var safeZonePollingTimer: Timer?
    private var zoneEventPollingTimer: Timer?
    
    // MARK: - Singleton
    static let shared = FirestoreService()
    
    // MARK: - Public Methods
    
    /// バス位置のリアルタイム監視を開始（AWS API専用）
    func startListening() {
        // 重複起動ガード: すでにポーリング中なら isLoading をリセットするだけ
        guard pollingTask == nil else {
            print("⏩ AWS REST API ポーリング既に実行中 - スキップ")
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        
        // AWS APIからポーリング開始
        startAWSPolling()
    }
    
    /// リアルタイム監視を停止
    func stopListening() {
        pollingTask?.cancel()
        pollingTask = nil
        print("🛑 デバイス位置監視停止")
    }
    
    // MARK: - 履歴取得（AWS API版）
    
    /// 指定した日付の位置履歴を取得(0時〜23時59分59秒)
    func fetchLocationHistory(for date: Date = Date()) {
        // タイムゾーンを明示してカレンダーを作成
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        
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
                
                // APIから返ってきたデータのタイプ内訳をログ出力
                let typeCounts = Dictionary(grouping: response.history, by: { $0.messageType.rawValue })
                    .mapValues(\.count)
                print("📊 履歴データ内訳: \(typeCounts)")

                // HistoryEntry → BusLocation に変換（GNSS のみ、GROUND_FIX は軌跡に含めない）
                let busLocations = response.history.compactMap { entry -> BusLocation? in
                    guard entry.messageType == .gnss,
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
                        busRoute: deviceId,
                        locationSource: .gnss
                    )
                }
                
                self.locationHistory = busLocations
                print("✅ 履歴データ取得: \(busLocations.count)件(GNSS) / 全\(response.count)件(\(dateString))")
                if busLocations.count < 2 {
                    print("⚠️ 軌跡表示には2件以上のGNSSデータが必要です（現在\(busLocations.count)件）")
                }
                
            } catch {
                print("❌ 履歴取得エラー: \(error)")
                if let decodingError = error as? DecodingError {
                    print("   デコードエラー詳細: \(decodingError)")
                }
                self.locationHistory = []
            }
        }
    }
    
    // MARK: - AWS REST API Polling
    
    /// AWS REST APIからのポーリングを開始
    private func startAWSPolling() {
        // 既存のタスクが動いていれば重複起動しない
        if pollingTask != nil {
            print("⏩ AWS REST API ポーリング既に実行中 - スキップ")
            return
        }
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
        
        // Task ベースの無限ループでポーリング
        // Timer.scheduledTimer と異なり RunLoop モードに依存しない
        pollingTask = Task {
            while !Task.isCancelled {
                await fetchLocationFromAWS(deviceId: deviceId)
                // キャンセルされていなければ 60 秒待機
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    break  // キャンセル時に脱出
                }
            }
            print("🛑 AWS REST API ポーリングタスク終了")
        }
    }
    
    /// AWS REST APIから位置情報を取得
    private func fetchLocationFromAWS(deviceId: String) async {
        do {
            print("🌐 AWS API: 位置情報取得開始 (deviceId: \(deviceId))")
            
            let deviceResponse = try await AWSNetworkService.shared.getDevices()
            
            guard let device = deviceResponse.devices.first(where: { $0.deviceId == deviceId }) else {
                errorMessage = "デバイスが見つかりません"
                isLoading = false
                return
            }
            
            if let location = device.lastLocation {
                let busLocation = BusLocation(
                    id: "\(deviceId)-\(location.timestamp)",
                    latitude: location.lat,
                    longitude: location.lon,
                    timestamp: Timestamp(date: location.date ?? Date()),
                    speed: nil,
                    azimuth: nil,
                    fromBusstopPole: nil,
                    toBusstopPole: nil,
                    busOperator: "nRF Device",
                    busRoute: deviceId,
                    locationSource: location.source == .groundFix ? .groundFix : .gnss
                )
                
                // @MainActor クラスなのでそのまま代入できる
                currentBusLocation = busLocation
                lastTemperature = device.lastTemperature  // 温度を保存
                errorMessage = nil
                isLoading = false
                
                print("✅ AWS API 位置情報取得成功: (\(location.lat), \(location.lon))")
                print("📍 測位方式: \(location.source.rawValue)")
                print("📏 精度: \(location.accuracy) m")
                if let temp = device.lastTemperature {
                    print("🌡️ 温度: \(temp.value)℃")
                }
                
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
                errorMessage = "位置情報がありません"
                isLoading = false
            }
            
        } catch {
            errorMessage = "AWS API エラー: \(error.localizedDescription)"
            isLoading = false
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
        // 既存のタイマーが動いていれば重複起動しない
        if safeZonePollingTimer != nil {
            print("⏩ セーフゾーン監視既に実行中 - スキップ")
            return
        }
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
    
    // MARK: - Zone Event Methods (AWS API /history 利用)

    /// 入退場イベントの監視を開始
    /// GET /devices/{deviceId}/history から ZONE_ENTER / ZONE_EXIT を取得する。
    /// - Parameters:
    ///   - childId: deviceId
    ///   - limit: 最大取得件数（デフォルト 100）
    func startListeningZoneEvents(childId: String, limit: Int = 100) {
        // 既存のタイマーが動いていれば重複起動しない
        if zoneEventPollingTimer != nil {
            print("⏩ ZoneEvent監視既に実行中 - スキップ")
            return
        }
        print("🚀 ZoneEvent監視開始: childId=\(childId), limit=\(limit)")

        // 初回取得
        Task {
            await fetchZoneEventsFromAWS(deviceId: childId, limit: limit)
        }

        // 5分ごとにポーリング
        zoneEventPollingTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchZoneEventsFromAWS(deviceId: childId, limit: limit)
            }
        }
    }

    /// AWS API から ZONE_ENTER / ZONE_EXIT の履歴を取得して zoneEvents に反映する。
    /// type パラメータが単一値しか受け付けないため、2回リクエストして結果をマージする。
    private func fetchZoneEventsFromAWS(deviceId: String, limit: Int) async {
        do {
            print("🌐 AWS API: ZoneEvent取得開始 (deviceId: \(deviceId))")

            // ZONE_ENTER と ZONE_EXIT をそれぞれ取得
            async let enterResponse = AWSNetworkService.shared.getHistory(
                deviceId: deviceId,
                type: .zoneEnter,
                start: nil,
                end: nil,
                limit: limit
            )
            async let exitResponse = AWSNetworkService.shared.getHistory(
                deviceId: deviceId,
                type: .zoneExit,
                start: nil,
                end: nil,
                limit: limit
            )

            let (enters, exits) = try await (enterResponse, exitResponse)

            // マージして timestamp 降順にソート
            let merged = (enters.history + exits.history)
                .sorted { lhs, rhs in
                    // Date に変換して比較、変換できない場合は文字列比較（ISO 8601 は辞書順で正しく比較できる）
                    let lhsDate = lhs.date ?? Date.distantPast
                    let rhsDate = rhs.date ?? Date.distantPast
                    return lhsDate > rhsDate
                }
                .prefix(limit)
                .map { $0 }

            // HistoryEntry を ZoneEvent に変換
            let events = merged.compactMap { entry -> ZoneEvent? in
                convertHistoryEntryToZoneEvent(entry, deviceId: deviceId)
            }

            await MainActor.run {
                self.zoneEvents = events
                print("✅ ZoneEvent取得成功: \(events.count)件（ENTER:\(enters.count) EXIT:\(exits.count)）")
            }

        } catch {
            print("❌ ZoneEvent取得エラー: \(error)")
        }
    }

    /// HistoryEntry（ZONE_ENTER / ZONE_EXIT）を ZoneEvent に変換
    private func convertHistoryEntryToZoneEvent(_ entry: HistoryEntry, deviceId: String) -> ZoneEvent? {
        guard entry.messageType == .zoneEnter || entry.messageType == .zoneExit,
              let zoneId = entry.zoneId,
              let zoneName = entry.zoneName,
              let date = entry.date
        else {
            return nil
        }

        let eventType: ZoneEvent.EventType = (entry.messageType == .zoneEnter) ? .enter : .exit

        // 位置情報がある場合は GeoPoint に変換
        let location = GeoPoint(
            latitude: entry.lat ?? 0.0,
            longitude: entry.lon ?? 0.0
        )

        return ZoneEvent(
            id: "\(deviceId)-\(entry.timestamp)",
            safeZoneId: zoneId,
            safeZoneName: zoneName,
            childId: deviceId,
            eventType: eventType,
            timestamp: date,
            location: location,
            notificationSent: false
        )
    }

    /// 入退場イベント監視を停止
    func stopListeningZoneEvents() {
        zoneEventPollingTimer?.invalidate()
        zoneEventPollingTimer = nil
        print("🛑 入退場イベント監視停止")
    }

    /// 手動で最新のZoneEventを再取得する
    func refreshZoneEvents(childId: String, limit: Int = 100) {
        Task {
            await fetchZoneEventsFromAWS(deviceId: childId, limit: limit)
        }
    }

    /// AWSプッシュ通知から受け取った入退場イベントを zoneEvents の先頭に追加する。
    /// - Parameter data: PushNotificationHandler がパースした PushNotificationData
    /// - Note: 同一 id が既に存在する場合は重複追加しない（冪等）
    func appendZoneEventFromPush(_ data: PushNotificationData) {
        let eventType: ZoneEvent.EventType = (data.type == .zoneEnter) ? .enter : .exit
        let location = GeoPoint(latitude: data.location.lat, longitude: data.location.lon)
        let date = data.detectedDate ?? Date()

        // id は "deviceId-detectedAt" で一意に識別
        let id = "\(data.deviceId)-\(data.detectedAt)"

        // 重複チェック
        guard !zoneEvents.contains(where: { $0.id == id }) else {
            print("⏩ 重複イベントのためスキップ: \(id)")
            return
        }

        let event = ZoneEvent(
            id: id,
            safeZoneId: data.zoneId,
            safeZoneName: data.zoneName,
            childId: data.deviceId,
            eventType: eventType,
            timestamp: date,
            location: location,
            notificationSent: true
        )

        // 先頭に挿入（新しい順を維持）
        zoneEvents.insert(event, at: 0)
        print("✅ プッシュ通知からZoneEvent追加: \(event.safeZoneName) (\(eventType.rawValue))")
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
