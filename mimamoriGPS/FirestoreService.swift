//
//  FirestoreService.swift
//  mimamoriGPS
//
//  Firestoreからバス位置データを取得
//

import Foundation
import FirebaseFirestore
import Combine

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
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var safeZoneListener: ListenerRegistration?
    private var zoneEventListener: ListenerRegistration?
    private var nrfCloudTimer: Timer?  // nRF Cloudポーリング用タイマー
    
    // MARK: - Data Source Selection
    
    /// nRF Cloudを使用するかどうか
    var useNRFCloud: Bool {
        return UserDefaults.standard.bool(forKey: "use_nrf_cloud")
    }
    
    /// データソースを切り替え
    func setDataSource(useNRFCloud: Bool) {
        UserDefaults.standard.set(useNRFCloud, forKey: "use_nrf_cloud")
        print("📍 データソース切り替え: \(useNRFCloud ? "nRF Cloud" : "公共交通DB")")
    }
    
    // MARK: - Singleton
    static let shared = FirestoreService()
    
    // MARK: - Public Methods
    
    /// バス位置のリアルタイム監視を開始
    func startListening() {
        isLoading = true
        errorMessage = nil
        
        if useNRFCloud {
            // nRF Cloudからポーリング
            startNRFCloudPolling()
        } else {
            // 公共交通DBから監視（既存）
            startFirestoreListener()
        }
    }
    
    // MARK: - Firestore Listener (既存の公共交通DB)
    
    private func startFirestoreListener() {
        print("🚀 Firebase監視開始...")
        print("   コレクション: latest_bus_location")
        print("   ドキュメント: current")
        
        // Firestoreの最新位置ドキュメントを監視
        listener = db.collection("latest_bus_location")
            .document("current")
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                print("📡 Firestore レスポンス受信")
                self.isLoading = false
                
                // エラーハンドリング
                if let error = error {
                    print("❌ Firebase接続エラー: \(error)")
                    self.handleFirestoreError(error: error, operation: "バス位置取得")
                    return
                }
                
                // ドキュメントが存在するか確認
                guard let document = documentSnapshot else {
                    print("❌ ドキュメントスナップショットがnull")
                    self.errorMessage = "データ取得に失敗しました"
                    return
                }
                
                print("📄 ドキュメント存在確認: \(document.exists)")
                
                if !document.exists {
                    self.errorMessage = "バス位置データが見つかりません。\nサーバー側の処理を確認してください。"
                    print("⚠️ Document does not exist - Cloud Functions may be stopped")
                    return
                }
                
                // データの内容をログ出力
                if let data = document.data() {
                    print("📋 取得データ:")
                    for (key, value) in data {
                        print("   \(key): \(value)")
                    }
                } else {
                    print("⚠️ データが空です")
                }
                
                // データの新しさを確認（5分以内のデータのみ有効）
                if let data = document.data(),
                   let timestamp = data["timestamp"] as? Timestamp {
                    let dataAge = Date().timeIntervalSince(timestamp.dateValue())
                    print("⏰ データ経過時間: \(Int(dataAge))秒")
                    if dataAge > 300 { // 5分 = 300秒
                        self.errorMessage = "データが古すぎます（\(Int(dataAge/60))分前）"
                        print("⚠️ Stale data: \(dataAge) seconds old")
                        return
                    }
                }
                
                // データをBusLocationモデルに変換
                do {
                    let location = try document.data(as: BusLocation.self)
                    self.currentBusLocation = location
                    self.errorMessage = nil
                    print("✅ バス位置取得成功: \(location.coordinate)")
                    
                    // 速度情報をログ出力
                    if let speed = location.speed {
                        print("🚀 現在速度: \(speed.toFixed(1)) km/h (\(location.transportMode == .walking ? "徒歩" : "乗り物"))")
                    }
                } catch {
                    self.errorMessage = "データ変換エラー: \(error.localizedDescription)"
                    print("❌ Decoding Error: \(error)")
                    print("   エラー詳細: \(error)")
                }
            }
    }
    
    // MARK: - Private Helper Methods
    
    /// Firestoreエラーの統一処理
    private func handleFirestoreError(error: Error, operation: String) {
        let nsError = error as NSError
        
        switch nsError.code {
        case 7: // PERMISSION_DENIED
            errorMessage = "アクセス権限がありません。設定を確認してください。"
        case 14: // UNAVAILABLE
            errorMessage = "ネットワーク接続を確認してください。"
        case 4: // DEADLINE_EXCEEDED
            errorMessage = "通信がタイムアウトしました。"
        default:
            errorMessage = "\(operation)エラー: \(error.localizedDescription)"
        }
        
        print("❌ \(operation) Error (\(nsError.code)): \(error.localizedDescription)")
    }
    
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
        
        db.collection("bus_locations")
            .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("timestamp", isLessThanOrEqualTo: Timestamp(date: endOfDay))
            .order(by: "timestamp", descending: false) // 古い順に取得
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                    
                if let error = error {
                    print("❌ 履歴取得エラー: \(error)")
                    return
                }
                    
                guard let documents = querySnapshot?.documents else {
                    print("⚠️ 履歴データが見つかりません")
                    self.locationHistory = []
                    return
                }
                    
                // ドキュメントをBusLocationモデルに変換
                self.locationHistory = documents.compactMap { document in
                    try? document.data(as: BusLocation.self)
                }
                    
                print("✅ 履歴データ取得: \(self.locationHistory.count)件(\(dateString))")
        }
    }
    
    // MARK: - nRF Cloud Polling
    
    /// nRF Cloudからのポーリングを開始
    private func startNRFCloudPolling() {
        print("🚀 nRF Cloud ポーリング開始...")
        
        // 設定確認
        guard NRFCloudConfig.isConfigured() else {
            errorMessage = "nRF Cloudの設定が必要です。設定画面でAPI KeyとDevice IDを入力してください。"
            isLoading = false
            return
        }
        
        // 初回取得
        Task {
            await fetchLocationFromNRFCloud()
        }
        
        // 60秒ごとにポーリング
        nrfCloudTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchLocationFromNRFCloud()
            }
        }
        
        print("✅ nRF Cloud ポーリング開始（60秒間隔）")
    }
    
    /// nRF Cloud APIから位置情報を取得
    @MainActor
    private func fetchLocationFromNRFCloud() async {
        let apiKey = NRFCloudConfig.apiKey
        let deviceID = NRFCloudConfig.deviceID
        
        guard !apiKey.isEmpty, !deviceID.isEmpty else {
            errorMessage = "nRF Cloud設定が未完了です"
            isLoading = false
            return
        }
        
        // nRF Cloud REST API呼び出し（最新20件を取得してGNSSデータを探す）
        let urlString = "https://api.nrfcloud.com/v1/location/history?deviceId=\(deviceID)&pageLimit=20"
        
        guard let url = URL(string: urlString) else {
            errorMessage = "無効なURL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("🌐 nRF Cloud API Request: GET \(urlString)")
        print("🔑 Authorization: Bearer \(apiKey.prefix(20))...")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "サーバーからの応答が無効です"
                isLoading = false
                return
            }
            
            print("📡 nRF Cloud API Response: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "不明なエラー"
                errorMessage = "APIエラー (\(httpResponse.statusCode)): \(errorBody)"
                isLoading = false
                return
            }
            
            // 🔍 レスポンスの生データをログ出力
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 nRF Cloud レスポンス:")
                print(jsonString)
            }
            
            // JSONパース
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ JSON解析失敗")
                errorMessage = "JSON解析エラー"
                isLoading = false
                return
            }
            
            print("✅ JSON解析成功")
            
            guard let items = json["items"] as? [[String: Any]] else {
                print("❌ itemsキーなし")
                errorMessage = "GPS データなし"
                isLoading = false
                return
            }
            
            print("📊 items要素数: \(items.count)")
            
            // GNSSデータのみをフィルタリング
            let gnssItems = items.filter { item in
                if let serviceType = item["serviceType"] as? String {
                    return serviceType == "GNSS"
                }
                return false
            }
            
            print("📡 GNSS データ数: \(gnssItems.count)/\(items.count)")
            
            // GNSSデータがあればそれを使用、なければ最新のデータを使用
            guard let item = gnssItems.first ?? items.first else {
                print("❌ items配列が空")
                errorMessage = "GPS データなし"
                isLoading = false
                return
            }
            
            if let serviceType = item["serviceType"] as? String {
                print("📍 使用する測位方式: \(serviceType)")
            }
            
            print("📍 取得データ:")
            for (key, value) in item {
                print("  \(key): \(value)")
            }
            
            // タイムスタンプの処理
            let timestamp: Timestamp
            if let ts = item["ts"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: ts) {
                    timestamp = Timestamp(date: date)
                } else {
                    timestamp = Timestamp(date: Date())
                }
            } else if let tsMillis = item["ts"] as? Int64 {
                timestamp = Timestamp(date: Date(timeIntervalSince1970: Double(tsMillis) / 1000.0))
            } else if let insertedAt = item["insertedAt"] as? String {
                // insertedAtをフォールバックとして使用
                let formatter = ISO8601DateFormatter()
                if let date = formatter.date(from: insertedAt) {
                    timestamp = Timestamp(date: date)
                } else {
                    timestamp = Timestamp(date: Date())
                }
            } else {
                timestamp = Timestamp(date: Date())
            }
            
            // 緯度経度の取得（文字列または数値に対応）
            let latitude: Double
            if let latDouble = item["lat"] as? Double {
                latitude = latDouble
            } else if let latString = item["lat"] as? String, let latDouble = Double(latString) {
                latitude = latDouble
            } else {
                latitude = 0
            }
            
            let longitude: Double
            if let lonDouble = item["lon"] as? Double {  // ⚠️ "lng"ではなく"lon"
                longitude = lonDouble
            } else if let lonString = item["lon"] as? String, let lonDouble = Double(lonString) {
                longitude = lonDouble
            } else {
                longitude = 0
            }
            
            print("🌍 パース結果: lat=\(latitude), lon=\(longitude)")
            
            // BusLocationに変換
            let busLocation = BusLocation(
                id: UUID().uuidString,
                latitude: latitude,
                longitude: longitude,
                timestamp: timestamp,
                speed: item["spd"] as? Double,
                azimuth: item["hdg"] as? Double,
                fromBusstopPole: nil,
                toBusstopPole: nil,
                busOperator: "nRF Device",
                busRoute: deviceID
            )
            
            self.currentBusLocation = busLocation
            self.errorMessage = nil
            self.isLoading = false
            
            print("✅ nRF Cloud 位置情報取得成功: (\(busLocation.latitude), \(busLocation.longitude))")
            
            if let speed = busLocation.speed {
                print("🚀 速度: \(speed.toFixed(1)) km/h")
            }
            
        } catch {
            errorMessage = "位置情報取得エラー: \(error.localizedDescription)"
            isLoading = false
            print("❌ nRF Cloud API エラー: \(error)")
        }
    }
    
    /// リアルタイム監視を停止
    func stopListening() {
        listener?.remove()
        listener = nil
        nrfCloudTimer?.invalidate()
        nrfCloudTimer = nil
        print("🛑 バス位置監視停止")
    }
    
    // MARK: - Safe Zone Methods
    
    /// セーフゾーンのリアルタイム監視を開始
    func startListeningSafeZones(childId: String) {
        print("🚀 セーフゾーン監視開始: childId=\(childId)")
        
        safeZoneListener = db.collection("safe_zones")
            .whereField("childId", isEqualTo: childId)
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ セーフゾーン取得エラー: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("⚠️ セーフゾーンが見つかりません")
                    self.safeZones = []
                    return
                }
                
                // ドキュメントをSafeZoneモデルに変換
                self.safeZones = documents.compactMap { document in
                    try? document.data(as: SafeZone.self)
                }
                
                print("✅ セーフゾーン取得: \(self.safeZones.count)件")
                for zone in self.safeZones {
                    print("  - \(zone.name): (\(zone.center.latitude), \(zone.center.longitude)), 半径:\(zone.radius)m")
                }
            }
    }
    
    /// セーフゾーン監視を停止
    func stopListeningSafeZones() {
        safeZoneListener?.remove()
        safeZoneListener = nil
        print("🛑 セーフゾーン監視停止")
    }
    
    /// セーフゾーンを追加
    func addSafeZone(_ zone: SafeZone, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try db.collection("safe_zones").document(zone.id ?? UUID().uuidString).setData(from: zone) { error in
                if let error = error {
                    print("❌ セーフゾーン追加エラー: \(error)")
                    completion(.failure(error))
                } else {
                    print("✅ セーフゾーン追加成功: \(zone.name)")
                    completion(.success(()))
                }
            }
        } catch {
            print("❌ セーフゾーンエンコードエラー: \(error)")
            completion(.failure(error))
        }
    }
    
    /// セーフゾーンを更新
    func updateSafeZone(_ zone: SafeZone, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let id = zone.id else {
            completion(.failure(NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Zone ID is missing"])))
            return
        }
        
        do {
            try db.collection("safe_zones").document(id).setData(from: zone) { error in
                if let error = error {
                    print("❌ セーフゾーン更新エラー: \(error)")
                    completion(.failure(error))
                } else {
                    print("✅ セーフゾーン更新成功: \(zone.name)")
                    completion(.success(()))
                }
            }
        } catch {
            print("❌ セーフゾーンエンコードエラー: \(error)")
            completion(.failure(error))
        }
    }
    
    /// セーフゾーンを削除
    func deleteSafeZone(_ zoneId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("safe_zones").document(zoneId).delete { error in
            if let error = error {
                print("❌ セーフゾーン削除エラー: \(error)")
                completion(.failure(error))
            } else {
                print("✅ セーフゾーン削除成功: \(zoneId)")
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Zone Event Methods
    
    /// 入退場イベントのリアルタイム監視を開始
    func startListeningZoneEvents(childId: String, limit: Int = 100) {
        print("🚀 ZoneEventListView.task 開始: childId=\(childId)")
        
        zoneEventListener = db.collection("zone_events")
            .whereField("childId", isEqualTo: childId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ イベント取得エラー: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("⚠️ イベントが見つかりません")
                    self.zoneEvents = []
                    return
                }
                
                // ドキュメントをZoneEventモデルに変換
                self.zoneEvents = documents.compactMap { document in
                    try? document.data(as: ZoneEvent.self)
                }
                
                print("✅ イベント取得: \(self.zoneEvents.count)件")
            }
    }
    
    /// 入退場イベント監視を停止
    func stopListeningZoneEvents() {
        zoneEventListener?.remove()
        zoneEventListener = nil
        print("🛑 入退場イベント監視停止")
    }
    
    // MARK: - FCM Token Methods
        
    /// FCMトークンを保存
    func saveFCMToken(_ token: String, forUserId userId: String) {
        let data: [String: Any] = [
            "fcmToken": token,
            "updatedAt": Timestamp(date: Date()),
            "platform": "iOS"
        ]
        
        db.collection("users").document(userId).setData(data, merge: true) { error in
            if let error = error {
                print("❌ FCMトークン保存エラー: \(error)")
            } else {
                print("✅ FCMトークン保存成功: \(token)")
            }
        }
    }
}
