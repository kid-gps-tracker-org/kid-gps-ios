//
//  MapView.swift
//  mimamoriGPS
//
//  デバイス位置を地図に表示（Firebase削除版）
//

import SwiftUI
import MapKit

struct MapView: View {
    let selectedDate: Date
    @ObservedObject var firestoreService: FirestoreService
    @Binding var mapCenter: CLLocationCoordinate2D  // 地図の中心位置をバインディング
    
    let childId: String  // Device IDを外部から受け取る
    
    // 選択された軌跡の位置情報
    @State private var selectedLocation: BusLocation?
    @State private var showLocationDetail = false
    
    // 地図の表示範囲（中心位置はバインディングから取得）
    @State private var region: MKCoordinateRegion
    
    // 地図の中心位置監視用のタイマー
    @State private var mapCenterUpdateTimer: Timer?
    
    // 前回の位置情報（アニメーション用）
    @State private var previousLocation: BusLocation?
    
    // アニメーション用の座標と色
    @State private var animatedCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)  // 座標を1つのオブジェクトに統合
    @State private var animatedColor: Color = .blue
    @State private var animatedScreenPosition: CGPoint = .zero  // 画面座標でアニメーション
    @State private var isMapRecentering: Bool = false  // 地図再センタリング中フラグ
    @State private var hasInitializedMarker: Bool = false  // マーカー初期化済みフラグ
    
    // 初期化時に地図の中心位置を設定
    init(
        selectedDate: Date,
        firestoreService: FirestoreService,
        mapCenter: Binding<CLLocationCoordinate2D>,
        childId: String
    ) {
        self.selectedDate = selectedDate
        self.firestoreService = firestoreService
        self._mapCenter = mapCenter
        self.childId = childId
        
        // 地図の初期表示範囲を設定
        self._region = State(initialValue: MKCoordinateRegion(
            center: mapCenter.wrappedValue,
            span: MKCoordinateSpan(
                latitudeDelta: 0.01,
                longitudeDelta: 0.01
            )
        ))
    }
    
    var body: some View {
        ZStack {
            // 1. 地図（一番下）
            Map(coordinateRegion: $region)
                .ignoresSafeArea()
                .onChange(of: region.center.latitude) { _, _ in
                    // 地図スクロール時に TrailOverlay / SafeZoneCircle の再描画をトリガー
                    // region は既に @State なので変化が伝播する（念のため明示的にコピー）
                    region = region
                }
                .onChange(of: region.span.latitudeDelta) { _, _ in
                    // ズーム変化時も再描画をトリガー
                    region = region
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // アプリがフォアグラウンドに戻った時に地図の中心を更新
                    if let location = firestoreService.currentBusLocation {
                        let newCenter = CLLocationCoordinate2D(
                            latitude: location.latitude,
                            longitude: location.longitude
                        )
                        if abs(mapCenter.latitude - newCenter.latitude) > 0.001 ||
                           abs(mapCenter.longitude - newCenter.longitude) > 0.001 {
                            withAnimation {
                                region.center = newCenter
                                mapCenter = newCenter
                            }
                        }
                    }
                }
            
            // 2. セーフゾーンの円（地図の上）
            if !firestoreService.safeZones.isEmpty {
                GeometryReader { geometry in
                    ForEach(firestoreService.safeZones) { zone in
                        SafeZoneCircle(
                            zone: zone,
                            region: $region,
                            geometry: geometry
                        )
                        .animation(.none)
                        .transition(.identity)
                        .transaction { transaction in
                            transaction.disablesAnimations = true
                            transaction.animation = nil
                        }
                    }
                }
                .allowsHitTesting(false)
                .animation(.none, value: firestoreService.safeZones)
                .transaction { transaction in
                    transaction.disablesAnimations = true
                    transaction.animation = nil
                }
            }
            
            // 3. 軌跡のティアドロップマーカー（アニメーション完全無効化）
            TrailOverlay(
                region: $region,
                locations: firestoreService.locationHistory,
                onTapLocation: { location in
                    selectedLocation = location
                    showLocationDetail = true
                }
            )
            .opacity(firestoreService.locationHistory.count >= 1 ? 1.0 : 0.0)
            .animation(.none)
            .transition(.identity)
            .transaction { transaction in
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
            
            // 4. 現在位置マーカー（測位方式によって表示を切り替え）
            if let location = firestoreService.currentBusLocation,
               Calendar.current.isDateInToday(selectedDate),
               hasInitializedMarker {
                GeometryReader { geometry in
                    if location.isGNSS {
                        // --- GNSS: 人アイコンマーカー ---
                        BusMarker(color: animatedColor)
                            .position(animatedScreenPosition)
                            .onChange(of: animatedCoordinate.latitude) { _, _ in
                                withAnimation(.easeInOut(duration: 1.2)) {
                                    animatedScreenPosition = convertToScreenPoint(
                                        latitude: animatedCoordinate.latitude,
                                        longitude: animatedCoordinate.longitude,
                                        region: region,
                                        size: geometry.size
                                    )
                                }
                            }
                            .onChange(of: region.center.latitude) { _, _ in
                                animatedScreenPosition = convertToScreenPoint(
                                    latitude: animatedCoordinate.latitude,
                                    longitude: animatedCoordinate.longitude,
                                    region: region,
                                    size: geometry.size
                                )
                            }
                            .onChange(of: region.center.longitude) { _, _ in
                                animatedScreenPosition = convertToScreenPoint(
                                    latitude: animatedCoordinate.latitude,
                                    longitude: animatedCoordinate.longitude,
                                    region: region,
                                    size: geometry.size
                                )
                            }
                            .onChange(of: geometry.size) { _, newSize in
                                animatedScreenPosition = convertToScreenPoint(
                                    latitude: animatedCoordinate.latitude,
                                    longitude: animatedCoordinate.longitude,
                                    region: region,
                                    size: newSize
                                )
                            }
                            .onAppear {
                                animatedScreenPosition = convertToScreenPoint(
                                    latitude: animatedCoordinate.latitude,
                                    longitude: animatedCoordinate.longitude,
                                    region: region,
                                    size: geometry.size
                                )
                            }
                    } else {
                        // --- GROUND_FIX: 居場所の可能性円 ---
                        GroundFixCircle(
                            coordinate: animatedCoordinate,
                            region: region,
                            geometry: geometry
                        )
                        .onChange(of: region.center.latitude) { _, _ in }  // 再描画トリガー
                        .onChange(of: region.center.longitude) { _, _ in }
                    }
                }
                .allowsHitTesting(false)
            } else {
                let _ = print("❌ 現在位置マーカー非表示理由:")
                let _ = print("   currentBusLocation: \(firestoreService.currentBusLocation != nil ? "あり" : "なし")")
                let _ = print("   isDateInToday: \(Calendar.current.isDateInToday(selectedDate))")
                let _ = print("   hasInitializedMarker: \(hasInitializedMarker)")
            }
            
            // 5. 上部の情報表示のみ
            VStack {
                if firestoreService.isLoading {
                    LoadingView()
                } else if let error = firestoreService.errorMessage {
                    ErrorView(message: error)
                } else if let location = firestoreService.currentBusLocation {
                    BusInfoCard(location: location, temperature: firestoreService.lastTemperature)
                } else {
                    // データが取得できていない場合
                    VStack(spacing: 8) {
                        Text("バス位置データがありません")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Text("Firestoreの設定やCloud Functionsの状態を確認してください")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(radius: 5)
                    )
                    .padding()
                }

                Spacer()
            }
            
            // 軌跡タップ時の詳細表示
            if showLocationDetail, let location = selectedLocation {
                LocationDetailOverlay(
                    location: location,
                    onDismiss: {
                        showLocationDetail = false
                        selectedLocation = nil
                    }
                )
            }
        }
        .onAppear {
            print("🎬 MapView.onAppear - 開始")
            
            // startListening / startListeningSafeZones は内部で重複起動ガード済み
            // → タブを切り替えて戻っても二重ポーリングにはならない
            firestoreService.startListening()
            firestoreService.startListeningSafeZones(childId: childId)
            
            // 軌跡を取得（タブに戻るたびに最新データを反映）
            firestoreService.fetchLocationHistory(for: selectedDate)
            
            // 地図の中心位置を監視するタイマーを開始
            startMapCenterMonitoring()
        }
        .onChange(of: selectedDate) { _, newDate in
            // 日付が変わった時だけ軌跡を再取得
            firestoreService.fetchLocationHistory(for: newDate)
        }
        .onChange(of: firestoreService.locationHistory) { _, newHistory in
            // 軌跡データが届いたとき、現在位置がまだ未取得なら軌跡の最新点に地図を移動
            guard firestoreService.currentBusLocation == nil,
                  let latest = newHistory.last else { return }
            let center = CLLocationCoordinate2D(
                latitude: latest.latitude,
                longitude: latest.longitude
            )
            print("🗺️ 現在位置未取得のため軌跡の最新点に地図を移動: (\(latest.latitude), \(latest.longitude))")
            region.center = center
            mapCenter = center
        }
        .onDisappear {
            // ポーリングはタブを離れても継続する（他タブでも位置情報を最新に保つため）
            // 地図UI専用のタイマーのみ停止
            stopMapCenterMonitoring()
        }
        .onChange(of: firestoreService.currentBusLocation) { oldLocation, newLocation in
            if let location = newLocation {
                print("🔄 位置情報更新検知:")
                print("   旧位置: \(oldLocation?.latitude ?? 0), \(oldLocation?.longitude ?? 0)")
                print("   新位置: \(location.latitude), \(location.longitude)")
                print("   旧色: \(oldLocation?.markerColor.description ?? "なし"), 新色: \(location.markerColor.description)")
                
                let newCenter = CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                )

                // 位置座標が変化した、かつ今日のデータを表示中であれば軌跡を再取得
                // （アプリ再起動なしに軌跡が積み上がっていくようにする）
                let coordinateChanged = oldLocation == nil
                    || abs((oldLocation?.latitude ?? 0) - location.latitude) > 0.000001
                    || abs((oldLocation?.longitude ?? 0) - location.longitude) > 0.000001
                if coordinateChanged && location.isGNSS && Calendar.current.isDateInToday(selectedDate) {
                    print("📍 GNSS位置変化を検知 → 軌跡を再取得")
                    firestoreService.fetchLocationHistory(for: selectedDate)
                }
                
                // 前回位置を更新（アニメーション用）
                self.previousLocation = oldLocation
                
                // 初回のデータ取得時は即座に地図を移動（アニメーションなし）
                if oldLocation == nil {
                    print("📍 初回データ取得 - 即座に地図を移動")
                    region.center = newCenter
                    mapCenter = newCenter
                    
                    // アニメーション座標と色を初期化
                    animatedCoordinate = newCenter
                    animatedColor = location.markerColor
                    hasInitializedMarker = true
                    print("🎨 マーカー初期化: 位置(\(location.latitude), \(location.longitude)), 色=\(location.markerColor.description)")
                    
                    // 注意: 画面座標はGeometryReaderのonAppearで計算される
                } else {
                    // 2回目以降は軌跡表示風の動作
                    print("🎬 マーカー移動アニメーション開始（位置と色を同時にアニメーション）")
                    print("   開始位置: (\(animatedCoordinate.latitude), \(animatedCoordinate.longitude))")
                    print("   目標位置: (\(location.latitude), \(location.longitude))")
                    print("   開始色: \(animatedColor.description)")
                    print("   目標色: \(location.markerColor.description)")
                    
                    let startTime = Date()
                    
                    // 座標を更新（1回の更新で緯度経度を同時に変更）
                    animatedCoordinate = newCenter
                    
                    // 画面座標のアニメーションはonChange(of: animatedCoordinate.latitude)で行われる
                    // ここでは色のみをアニメーション
                    withAnimation(.easeInOut(duration: 1.2)) {
                        animatedColor = location.markerColor
                    }
                    
                    print("⏱️ アニメーション開始時刻: \(startTime)")
                    
                    // 2. マーカーの移動が完了した後、地図を再センタリング（0.8秒）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        let elapsedTime = Date().timeIntervalSince(startTime)
                        print("⏱️ 1.2秒タイマー発火: 実際の経過時間=\(elapsedTime)秒")
                        print("🗺️ 地図の再センタリング開始（マーカーは既に目標位置なので動かない）")
                        
                        // 地図再センタリング中フラグをON
                        isMapRecentering = true
                        
                        // 地図のみをアニメーション
                        withAnimation(.easeInOut(duration: 0.8)) {
                            region.center = newCenter
                            mapCenter = newCenter
                        }
                        
                        // 再センタリング完了後にフラグをOFF
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            isMapRecentering = false
                            print("✅ 地図の再センタリング完了")
                            
                            // 再センタリング後、画面座標はonChange(of: region)で自動的に再計算される
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 2つの位置間の距離を計算
    private func calculateDistance(from: BusLocation, to: BusLocation) -> Double {
        return sqrt(
            pow(to.latitude - from.latitude, 2) +
            pow(to.longitude - from.longitude, 2)
        )
    }
    

        
    /// 地図の中心位置監視を開始
    private func startMapCenterMonitoring() {
        mapCenterUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // 地図の中心が大幅に変わった場合のみバインディングを更新
            let threshold = 0.0005 // より小さな閾値で頻繁な更新を避ける
            if abs(mapCenter.latitude - region.center.latitude) > threshold ||
               abs(mapCenter.longitude - region.center.longitude) > threshold {
                mapCenter = region.center
            }
        }
    }
    
    /// 地図の中心位置監視を停止
    private func stopMapCenterMonitoring() {
        mapCenterUpdateTimer?.invalidate()
        mapCenterUpdateTimer = nil
    }
        
    /// 選択日付をフォーマット（表示用）
    private func formatSelectedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: date)
        
        if selectedDay == today {
            return "今日"
        } else if calendar.isDate(selectedDay, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today)!) {
            return "昨日"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M月d日"
            formatter.locale = Locale(identifier: "ja_JP")
            return formatter.string(from: date)
        }
    }
    
    /// 緯度経度を画面座標に変換
    private func convertToScreenPoint(
        latitude: Double,
        longitude: Double,
        region: MKCoordinateRegion,
        size: CGSize
    ) -> CGPoint {
        let centerLat = region.center.latitude
        let centerLon = region.center.longitude
        
        let spanLat = region.span.latitudeDelta
        let spanLon = region.span.longitudeDelta
        
        let normalizedX = (longitude - centerLon) / spanLon
        let normalizedY = (centerLat - latitude) / spanLat
        
        let x = size.width * (0.5 + normalizedX)
        let y = size.height * (0.5 + normalizedY)
        
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Supporting Views

/// GNSS 用：人アイコンマーカー（点滅なし）
struct BusMarker: View {
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
            Image(systemName: "person.fill")
                .foregroundColor(.white)
                .font(.system(size: 14))
        }
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 30, height: 30)
        )
        .frame(width: 30, height: 30)
        .shadow(radius: 3)
    }
}

/// GROUND_FIX 用：居場所の可能性を示す半透明の円
struct GroundFixCircle: View {
    let coordinate: CLLocationCoordinate2D
    let region: MKCoordinateRegion
    let geometry: GeometryProxy

    /// セルラー測位の典型的な精度（約 500〜1000 m）を画面ピクセルに換算
    private var radiusInPoints: CGFloat {
        // 経度方向の 1 度あたりのピクセル数
        let pointsPerLonDegree = geometry.size.width / region.span.longitudeDelta
        // 約 500 m を経度差に換算（緯度によって変わるが、日本では 1° ≒ 91 km）
        let metersPerLonDegree = 111_320.0 * cos(coordinate.latitude * .pi / 180)
        let lonDeltaFor500m = 500.0 / metersPerLonDegree
        return CGFloat(lonDeltaFor500m) * pointsPerLonDegree
    }

    private var center: CGPoint {
        let centerLat = region.center.latitude
        let centerLon = region.center.longitude
        let spanLat = region.span.latitudeDelta
        let spanLon = region.span.longitudeDelta
        let x = geometry.size.width  * (0.5 + (coordinate.longitude - centerLon) / spanLon)
        let y = geometry.size.height * (0.5 - (coordinate.latitude  - centerLat) / spanLat)
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        ZStack {
            // 外枠（ストローク）
            Circle()
                .stroke(Color.orange.opacity(0.8), lineWidth: 2)
                .frame(width: radiusInPoints * 2, height: radiusInPoints * 2)

            // 塗りつぶし（半透明）
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: radiusInPoints * 2, height: radiusInPoints * 2)

            // 中心の小ドット
            Circle()
                .fill(Color.orange.opacity(0.7))
                .frame(width: 10, height: 10)

            // ラベル
            VStack(spacing: 2) {
                Spacer().frame(height: radiusInPoints + 6)
                Text("圏内にいる可能性")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color(.systemBackground).opacity(0.85))
                    )
            }
        }
        .position(center)
    }
}

/// バス情報カード
struct BusInfoCard: View {
    let location: BusLocation
    var temperature: Temperature?

    // 設定から表示名を取得
    private var deviceDisplayName: String {
        UserDefaults.standard.string(forKey: "device_display_name") ?? "デバイス"
    }
    
    // データが古いかチェック（1時間以上更新されていない場合）
    private var isDataStale: Bool {
        let timeSinceUpdate = Date().timeIntervalSince(location.date)
        return timeSinceUpdate > 3600 // 1時間 = 3600秒
    }
    
    // データの古さを表示用テキストに変換
    private var dataAgeText: String {
        let timeSinceUpdate = Date().timeIntervalSince(location.date)
        let hours = Int(timeSinceUpdate / 3600)
        let days = hours / 24
        
        if days > 0 {
            return "\(days)日前"
        } else if hours > 0 {
            return "\(hours)時間前"
        } else {
            return "最新"
        }
    }

    // 温度に応じた色
    private func temperatureColor(_ value: Double) -> Color {
        switch value {
        case ..<10:  return .blue    // 寒い
        case ..<25:  return .green   // 適温
        case ..<30:  return .orange  // やや暑い
        default:     return .red     // 暑い
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: location.isGNSS ? "person.fill" : "antenna.radiowaves.left.and.right")
                    .foregroundColor(location.isGNSS ? .blue : .orange)
                Text(deviceDisplayName)
                    .font(.headline)
                Spacer()
                // 測位方式バッジ
                Text(location.isGNSS ? "GPS" : "セルラー")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(location.isGNSS ? .blue : .orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((location.isGNSS ? Color.blue : Color.orange).opacity(0.15))
                    )
            }

            // セルラー測位の注意書き
            if !location.isGNSS {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("屋内にいる可能性があります（概算位置を表示中）")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.1))
                )
            }
            
            // データ更新警告
            if isDataStale {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("データが\(dataAgeText)更新されていません")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.1))
                )
            }
            
            // 時刻・速度・温度を横並びに配置
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.gray)
                    Text(formatDate(location.date))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()

                // 温度
                if let temp = temperature {
                    HStack(spacing: 3) {
                        Image(systemName: "thermometer.medium")
                            .foregroundColor(temperatureColor(temp.value))
                        Text(String(format: "%.1f℃", temp.value))
                            .font(.subheadline)
                            .foregroundColor(temperatureColor(temp.value))
                    }
                }
                
                if let speed = location.speed {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f km/h", speed))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
        .padding()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

/// ローディング表示
struct LoadingView: View {
    @State private var loadingText = "GPS位置取得中"
    @State private var dotCount = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(loadingText + String(repeating: ".", count: dotCount))
                .font(.subheadline)
                .onAppear {
                    startLoadingAnimation()
                }
                .onDisappear {
                    timer?.invalidate()
                    timer = nil
                }
            
            #if targetEnvironment(simulator)
            Text("シミュレーターではモックデータを3秒後に表示")
                .font(.caption2)
                .foregroundColor(.orange)
                .padding(.top, 4)
            #endif
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
        .padding()
    }
    
    private func startLoadingAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                dotCount = (dotCount + 1) % 4
            }
        }
    }
}

/// エラー表示
struct ErrorView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
        .padding()
    }
}

// MARK: - Teardrop Components

// HalfCircleMarker は HalfCircleMarker.swift ファイルで定義されています

/*
/// ティアドロップ（水滴）形状
struct TeardropShape: Shape {
    
}

/// 軌跡用の小さなティアドロップマーカー
struct TrailMarker: View {
    
}
*/
// MARK: - Trail Overlay

/// 軌跡をティアドロップマーカーで表示（シンプルフェード）
struct TrailOverlay: View {
    @Binding var region: MKCoordinateRegion
    let locations: [BusLocation]
    let onTapLocation: (BusLocation) -> Void
    
    // 各位置データに方位角を付与した表示用データを作成
    // 次の点がある場合はその方向を、最後の1点は直前の点からの方向を使う
    private var locationItems: [(location: BusLocation, azimuth: Double, index: Int)] {
        guard !locations.isEmpty else { return [] }

        return locations.indices.map { index in
            let azimuth: Double
            if index < locations.count - 1 {
                // 次の点が存在する → 次点への方位角
                azimuth = calculateAzimuth(from: locations[index], to: locations[index + 1])
            } else if locations.count >= 2 {
                // 最後の点 → 直前の点からの方位角を使い回す
                azimuth = calculateAzimuth(from: locations[index - 1], to: locations[index])
            } else {
                // 1点のみ → 向き不明のため0（北向き）
                azimuth = 0
            }
            return (location: locations[index], azimuth: azimuth, index: index)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            // データがない場合は何も表示しない
            if locationItems.isEmpty {
                EmptyView()
            } else {
                // 軌跡上の各ポイントにマーカー
                ForEach(locationItems, id: \.index) { item in
                    // 時間ベースで透過度を計算
                    let opacity = calculateOpacity(location: item.location)

                    HalfCircleMarker(
                        azimuth: item.azimuth,
                        opacity: opacity,
                        color: item.location.markerColor
                    )
                    .frame(width: 44, height: 44)  // タップ領域を拡大
                    .contentShape(Rectangle())      // 透明部分もタップ可能に
                    .position(
                        convertToScreenPoint(
                            latitude: item.location.latitude,
                            longitude: item.location.longitude,
                            region: region,
                            size: geometry.size
                        )
                    )
                    .animation(.none)
                    .transition(.identity)
                    .transaction { transaction in
                        transaction.disablesAnimations = true
                        transaction.animation = nil
                    }
                    .onTapGesture {
                        onTapLocation(item.location)
                    }
                }
                .animation(.none)
                .transaction { transaction in
                    transaction.disablesAnimations = true
                }
            }
        }
        .animation(.none)
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
        .transition(.identity)
        .animation(nil)
        .drawingGroup()  // レンダリング最適化でアニメーション副作用を防止
    }
    
    /// 緯度経度を画面座標に変換
    private func convertToScreenPoint(
        latitude: Double,
        longitude: Double,
        region: MKCoordinateRegion,
        size: CGSize
    ) -> CGPoint {
        // 地図の中心からの相対位置を計算
        let centerLat = region.center.latitude
        let centerLon = region.center.longitude
        
        let spanLat = region.span.latitudeDelta
        let spanLon = region.span.longitudeDelta
        
        // 正規化された位置（-0.5 ~ 0.5）
        let normalizedX = (longitude - centerLon) / spanLon
        let normalizedY = (centerLat - latitude) / spanLat
        
        // 画面座標に変換
        let x = size.width * (0.5 + normalizedX)
        let y = size.height * (0.5 + normalizedY)
        
        return CGPoint(x: x, y: y)
    }
    
    /// 2点間の方位角を計算（度）
    private func calculateAzimuth(from: BusLocation, to: BusLocation) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        var azimuth = atan2(y, x) * 180 / .pi
        azimuth = (azimuth + 360).truncatingRemainder(dividingBy: 360)
        
        return azimuth
    }
    
    /// 透過度を計算（時間ベース）
    private func calculateOpacity(location: BusLocation) -> Double {
        let now = Date()
        let locationTime = location.timestamp.dateValue()
        
        // 現在時刻からの経過時間（秒）
        let elapsedSeconds = now.timeIntervalSince(locationTime)
        let elapsedHours = elapsedSeconds / 3600.0
        
        // 透過度の計算
        // 0～4時間前: 0.7（濃い）
        // 4～8時間前: 0.5（中間）
        // 8時間以上: 0.25（薄い）
        
        if elapsedHours <= 4 {
            return 0.7  // 4時間以内は濃い
        } else if elapsedHours <= 8 {
            return 0.5  // 4～8時間は中間
        } else {
            return 0.25  // 8時間以上は薄い
        }
    }
}

// MARK: - Safe Zone Components

/// セーフゾーンの円（アニメーション無効化版）
struct SafeZoneCircle: View {
    let zone: SafeZone
    @Binding var region: MKCoordinateRegion
    let geometry: GeometryProxy
    
    var body: some View {
        let center = convertToScreenPoint(
            latitude: zone.centerLat,
            longitude: zone.centerLon,
            region: region,
            size: geometry.size
        )
        
        let radius = metersToPixels(
            meters: zone.radius,
            latitude: zone.centerLat,
            region: region,
            screenHeight: geometry.size.height
        )
        
        ZStack {
            // 塗りつぶし円
            Circle()
                .fill(Color(hex: zone.color).opacity(0.2))
                .frame(width: radius * 2, height: radius * 2)
            
            // 枠線
            Circle()
                .stroke(Color(hex: zone.color), lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)
        }
        .position(center)
        .animation(.none)
        .transition(.identity)
        .transaction { transaction in
            transaction.disablesAnimations = true
            transaction.animation = nil
        }
    }
    
    /// 緯度経度を画面座標に変換
    private func convertToScreenPoint(
        latitude: Double,
        longitude: Double,
        region: MKCoordinateRegion,
        size: CGSize
    ) -> CGPoint {
        let centerLat = region.center.latitude
        let centerLon = region.center.longitude
        
        let spanLat = region.span.latitudeDelta
        let spanLon = region.span.longitudeDelta
        
        let normalizedX = (longitude - centerLon) / spanLon
        let normalizedY = (centerLat - latitude) / spanLat
        
        let x = size.width * (0.5 + normalizedX)
        let y = size.height * (0.5 + normalizedY)
        
        return CGPoint(x: x, y: y)
    }
    
    /// メートルをピクセルに変換
    private func metersToPixels(
        meters: Double,
        latitude: Double,
        region: MKCoordinateRegion,
        screenHeight: CGFloat
    ) -> CGFloat {
        // 緯度1度あたりの距離（メートル）
        let metersPerDegree = 111000.0
        
        // 画面の高さが地図上で何度に相当するか
        let degreesPerScreen = region.span.latitudeDelta
        
        // 画面の高さが何メートルに相当するか
        let metersPerScreen = degreesPerScreen * metersPerDegree
        
        // メートルをピクセルに変換
        let pixelsPerMeter = Double(screenHeight) / metersPerScreen
        
        return CGFloat(meters * pixelsPerMeter)
    }
}

// MARK: - Location Detail Overlay

/// 軌跡タップ時の詳細表示
struct LocationDetailOverlay: View {
    let location: BusLocation
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // 背景（タップで閉じる）
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // 詳細カード
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("軌跡の詳細")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title3)
                    }
                }
                
                Divider()
                
                // タイムスタンプ
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("時刻")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatDateTime(location.timestamp.dateValue()))
                        .font(.body)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 20)
            )
            .padding(.horizontal, 40)
        }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    MapView(
        selectedDate: Date(),
        firestoreService: FirestoreService(),
        mapCenter: .constant(CLLocationCoordinate2D(latitude: 35.4437, longitude: 139.6380)),
        childId: "nrf-359404230006463"
    )
}
