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
    
    // MARK: - Singleton
    static let shared = FirestoreService()
    
    // MARK: - Public Methods
    
    /// バス位置のリアルタイム監視を開始
    func startListening() {
        isLoading = true
        errorMessage = nil
        
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
    
    /// リアルタイム監視を停止
    func stopListening() {
        listener?.remove()
        listener = nil
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
