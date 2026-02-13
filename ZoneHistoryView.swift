//
//  ZoneHistoryView.swift
//  mimamoriGPS
//
//  セーフゾーン入退場履歴画面
//  GET /devices/{deviceId}/history?type=ZONE_ENTER および ZONE_EXIT を使用
//

import SwiftUI

struct ZoneHistoryView: View {
    // MARK: - Properties

    let childId: String

    @StateObject private var dataService = DataService.shared
    @State private var isRefreshing = false

    // MARK: - Body

    var body: some View {
        Group {
            if dataService.isLoading && dataService.zoneHistory.isEmpty {
                loadingView
            } else if dataService.zoneHistory.isEmpty {
                emptyStateView
            } else {
                historyList
            }
        }
        .navigationTitle("入退場履歴")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
        .task {
            await dataService.fetchZoneHistory()
        }
        .alert("エラー", isPresented: Binding(
            get: { dataService.errorMessage != nil },
            set: { if !$0 { dataService.errorMessage = nil } }
        )) {
            Button("OK") { dataService.errorMessage = nil }
        } message: {
            Text(dataService.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    /// ローディング表示
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("履歴を取得中...")
                .foregroundColor(.secondary)
        }
    }

    /// 空の状態
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("入退場履歴がありません")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("セーフゾーンの入退場が検出されると\nここに記録されます")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("再読み込み") {
                Task { await refresh() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    /// 履歴リスト
    private var historyList: some View {
        List {
            ForEach(Array(dataService.zoneHistory.enumerated()), id: \.offset) { _, entry in
                ZoneHistoryRow(entry: entry)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await refresh()
        }
    }

    // MARK: - Methods

    private func refresh() async {
        isRefreshing = true
        await dataService.fetchZoneHistory()
        isRefreshing = false
    }
}

// MARK: - ZoneHistoryRow

struct ZoneHistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 14) {
            // イベント種別アイコン
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                // ゾーン名 + イベント種別
                Text(eventLabel)
                    .font(.system(size: 16, weight: .medium))

                // 日時
                if let date = entry.date {
                    Text(date, style: .relative)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(formattedDate(date))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Text(entry.timestamp)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                // 精度（位置情報がある場合）
                if let accuracy = entry.accuracy {
                    Text("精度: \(Int(accuracy)) m")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Computed Properties

    private var iconName: String {
        entry.messageType == .ZONE_ENTER ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
    }

    private var iconBackgroundColor: Color {
        entry.messageType == .ZONE_ENTER ? .green : .orange
    }

    private var eventLabel: String {
        let zoneName = entry.zoneName ?? "不明なゾーン"
        switch entry.messageType {
        case .ZONE_ENTER:
            return "「\(zoneName)」に入場"
        case .ZONE_EXIT:
            return "「\(zoneName)」から退場"
        default:
            return zoneName
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ZoneHistoryView(childId: "nrf-352656100123456")
    }
}
