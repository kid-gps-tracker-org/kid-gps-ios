//
//  ContentView.swift
//  mimamoriGPS
//
//  タブバー視認性改善版
//

import SwiftUI
import MapKit
import FirebaseCore

struct ContentView: View {
    @State private var selectedTab = 1  // 地図タブをデフォルトに
    @State private var showDatePicker = false
    @State private var selectedDate = Date()
    
    // FirestoreServiceを共有するために
    @StateObject private var firestoreService = FirestoreService()
    
    // デバッグ用のエラー状態
    @State private var debugError: String?
    
    // 地図の中心位置を共有（初期値は横浜駅周辺）
    @State private var mapCenter = CLLocationCoordinate2D(
        latitude: 35.4437,
        longitude: 139.6380
    )
    
    init() {
        // タブバーの外観をカスタマイズ
        let appearance = UITabBarAppearance()
        
        // 背景を不透明な白に設定
        appearance.backgroundColor = UIColor.systemBackground
        
        // 影を追加
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)
        appearance.shadowImage = UIImage()
        
        // アイコンとテキストの色設定
        // 非選択時の色（グレー）
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray,
            .font: UIFont.systemFont(ofSize: 11, weight: .medium)
        ]
        
        // 選択時の色（青）
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .font: UIFont.systemFont(ofSize: 11, weight: .bold)
        ]
        
        // 標準とスクロール時の両方に適用
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        VStack {
            // デバッグ情報を表示
            if let debugError = debugError {
                Text("Debug Error: \(debugError)")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.yellow.opacity(0.3))
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            
            TabView(selection: $selectedTab) {
            // 今日タブ（日付選択）
            DateSelectionView(
                selectedDate: $selectedDate,
                firestoreService: firestoreService
            )
            .tabItem {
                Label {
                    Text("今日")
                        .font(.system(size: 11, weight: selectedTab == 0 ? .bold : .medium))
                } icon: {
                    Image(systemName: selectedTab == 0 ? "calendar.circle.fill" : "calendar")
                        .font(.system(size: 24, weight: .medium))
                }
            }
            .tag(0)
            
            // 地図タブ
            MapView(
                selectedDate: selectedDate, 
                firestoreService: firestoreService,
                mapCenter: $mapCenter
            )
            .transition(.identity)  // トランジション無効化
            .animation(nil)  // アニメーション無効化
            .transaction { transaction in
                transaction.disablesAnimations = true  // 地図タブの全アニメーション強制無効化
            }
                .tabItem {
                    Label {
                        Text("地図")
                            .font(.system(size: 11, weight: selectedTab == 1 ? .bold : .medium))
                    } icon: {
                        Image(systemName: selectedTab == 1 ? "map.fill" : "map")
                            .font(.system(size: 24, weight: .medium))
                    }
                }
                .tag(1)
            
            // イベント履歴タブ
            ZoneEventListView(childId: "test-child-001")
                .tabItem {
                    Label {
                        Text("履歴")
                            .font(.system(size: 11, weight: selectedTab == 2 ? .bold : .medium))
                    } icon: {
                        Image(systemName: selectedTab == 2 ? "clock.fill" : "clock")
                            .font(.system(size: 24, weight: .medium))
                    }
                }
                .tag(2)
            
            // セーフゾーンタブ
            SafeZoneListView(childId: "test-child-001")
                .tabItem {
                    Label {
                        Text("セーフゾーン")
                            .font(.system(size: 11, weight: selectedTab == 3 ? .bold : .medium))
                    } icon: {
                        Image(systemName: selectedTab == 3 ? "shield.fill" : "shield")
                            .font(.system(size: 24, weight: .medium))
                    }
                }
                .tag(3)
        }
        .accentColor(.blue)  // 選択時の色を明示的に指定
        .animation(nil, value: selectedTab)  // タブ切り替えアニメーションを無効化
        .transaction { transaction in
            transaction.disablesAnimations = true  // 全てのアニメーションを無効化
        }
        .onAppear {
            // Firebase接続テスト
            testFirebaseConnection()
        }
        }
    }
    
    // MARK: - Firebase Connection Test
    
    /// Firebase接続をテストして問題を診断
    private func testFirebaseConnection() {
        print("🔍 Firebase接続テスト開始...")
        
        // Firebase Appが正しく設定されているかテスト
        if FirebaseApp.app() != nil {
            print("✅ FirebaseApp が初期化されています")
        } else {
            debugError = "FirebaseApp が初期化されていません"
            print("❌ FirebaseApp が初期化されていません")
            return
        }
        
        // Firestore接続テスト
        firestoreService.startListening()
        
        // エラーメッセージを監視
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if let errorMessage = firestoreService.errorMessage {
                debugError = errorMessage
                print("❌ Firestore接続エラー: \(errorMessage)")
            } else {
                print("✅ Firebase接続テスト完了")
            }
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - Date Selection View

/// 日付選択専用ビュー
struct DateSelectionView: View {
    @Binding var selectedDate: Date
    let firestoreService: FirestoreService
    
    // 選択可能な日付の範囲を計算
    private var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 7日前の日付を計算
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        
        return sevenDaysAgo...today
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("軌跡を表示する日付を選択")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                // 現在選択中の日付表示
                VStack(spacing: 8) {
                    Text("現在選択中")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(formatSelectedDate(selectedDate))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                
                // データ保持期間の説明
                Text("※ 直近7日間のデータのみ保存されています")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                
                // 日付選択器
                DatePicker(
                    "日付を選択",
                    selection: $selectedDate,
                    in: dateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .onChange(of: selectedDate) { _, newDate in
                    // 日付が変更されたら履歴を再取得
                    firestoreService.fetchLocationHistory(for: newDate)
                }
                
                Spacer()
            }
            .navigationTitle("日付選択")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    /// 選択日付をフォーマット
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
            formatter.dateFormat = "M月d日(E)"
            formatter.locale = Locale(identifier: "ja_JP")
            return formatter.string(from: date)
        }
    }
}
