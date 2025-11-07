//
//  ZoneEventListView.swift
//  mimamoriGPS
//
//  セーフゾーンイベント履歴画面
//

import SwiftUI

struct ZoneEventListView: View {
    // MARK: - Properties
    @StateObject private var firestoreService = FirestoreService()
    
    let childId: String
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Group {
                if firestoreService.zoneEvents.isEmpty {
                    // 空の状態
                    emptyStateView
                } else {
                    // イベントリスト
                    eventList
                }
            }
            .navigationTitle("イベント履歴")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                print("🚀 ZoneEventListView.task 開始: childId=\(childId)")
                firestoreService.startListeningZoneEvents(childId: childId, limit: 100)
            }
            .onDisappear {
                print("🛑 ZoneEventListView 終了")
            }
        }
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
            ForEach(firestoreService.zoneEvents) { event in
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
                    Text(formatTime(event.timestamp.dateValue()))
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                
                // 日付
                Text(formatDate(event.timestamp.dateValue()))
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
        ZoneEventListView(childId: "test-child-001")
    }
}
