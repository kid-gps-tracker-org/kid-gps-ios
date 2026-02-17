//
//  ZoneEventListView.swift
//  mimamoriGPS
//
//  セーフゾーンイベント履歴画面
//

import SwiftUI

struct ZoneEventListView: View {
    // MARK: - Properties

    /// ContentView から共有インスタンスを受け取る（独自生成しない）
    @ObservedObject var firestoreService: FirestoreService
    
    let childId: String

    /// 表示する日付（ContentView の selectedDate と同期）
    @Binding var selectedDate: Date

    // MARK: - Computed Properties

    /// 選択日でフィルタリングされたイベント一覧
    private var filteredEvents: [ZoneEvent] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        return firestoreService.zoneEvents.filter { event in
            event.timestamp >= startOfDay && event.timestamp < endOfDay
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            Group {
                if filteredEvents.isEmpty {
                    // 空の状態
                    emptyStateView
                } else {
                    // イベントリスト
                    eventList
                }
            }
            .navigationTitle("イベント履歴")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                datePicker
            }
            .task {
                print("🚀 ZoneEventListView.task 開始: childId=\(childId)")
                // startListeningZoneEvents は内部で重複起動ガード済み
                firestoreService.startListeningZoneEvents(childId: childId, limit: 500)
            }
            .onDisappear {
                print("🛑 ZoneEventListView 終了")
            }
        }
    }

    // MARK: - Date Picker

    private var datePicker: some View {
        VStack(spacing: 0) {
            DatePicker(
                "日付",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()
        }
        .background(.bar)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("イベント履歴がありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("セーフゾーンへの入退場が記録されます")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Event List
    
    private var eventList: some View {
        List {
            ForEach(filteredEvents) { event in
                ZoneEventRow(event: event)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - ZoneEventRow

struct ZoneEventRow: View {
    let event: ZoneEvent
    
    var body: some View {
        HStack(spacing: 16) {
            // イベントタイプアイコン
            eventIcon
            
            VStack(alignment: .leading, spacing: 6) {
                // ゾーン名
                Text(event.safeZoneName)
                    .font(.system(size: 17, weight: .semibold))
                
                // イベントタイプ
                HStack(spacing: 4) {
                    Text(event.eventType == .enter ? "入場" : "退場")
                        .font(.system(size: 15))
                        .foregroundColor(event.eventType == .enter ? .green : .red)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    
                    // 時刻
                    Text(formatTime(event.timestamp))
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                
                // 日付
                Text(formatDate(event.timestamp))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Event Icon
    
    private var eventIcon: some View {
        ZStack {
            Circle()
                .fill(event.eventType == .enter ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .frame(width: 50, height: 50)
            
            Image(systemName: event.eventType == .enter ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(event.eventType == .enter ? .green : .red)
        }
    }
    
    // MARK: - Helper Methods
    
    /// 時刻をフォーマット (HH:mm)
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    /// 日付をフォーマット (yyyy/MM/dd)
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct ZoneEventListView_Previews: PreviewProvider {
    static var previews: some View {
        ZoneEventListView(
            firestoreService: FirestoreService(),
            childId: "test-child-001",
            selectedDate: .constant(Date())
        )
    }
}
