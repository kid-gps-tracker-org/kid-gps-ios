//
//  SettingsView.swift
//  mimamoriGPS
//
//  設定画面 - すべてのユーザー設定をまとめたハブ
//

import SwiftUI

// MARK: - 設定項目の定義（今後の追加もここに足すだけ）

private struct SettingsItem: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let destination: AnyView
}

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var firestoreService: FirestoreService
    let childId: String

    // NavigationLink から戻ったときも最新値を反映するため @State で持つ
    @State private var isAWSConfigured = AWSNetworkService.shared.isConfigured()

    var body: some View {
        NavigationView {
            List {
                // ── みまもり設定 ──
                Section {
                    NavigationLink {
                        SafeZoneListView(
                            firestoreService: firestoreService,
                            childId: childId
                        )
                        .navigationBarBackButtonHidden(false)
                    } label: {
                        SettingsRow(
                            icon: "shield.fill",
                            iconColor: .blue,
                            title: "セーフゾーン",
                            subtitle: "\(firestoreService.safeZones.count)件設定中"
                        )
                    }
                } header: {
                    Text("みまもり設定")
                }

                // ── 接続・API ──
                Section {
                    NavigationLink {
                        NRFCloudSettingsView()
                            .onDisappear {
                                // 設定画面から戻ったら状態を更新
                                isAWSConfigured = AWSNetworkService.shared.isConfigured()
                            }
                    } label: {
                        SettingsRow(
                            icon: "antenna.radiowaves.left.and.right",
                            iconColor: isAWSConfigured ? .green : .orange,
                            title: "AWS API設定",
                            subtitle: isAWSConfigured ? "設定済み" : "未設定",
                            badge: isAWSConfigured ? nil : "要設定"
                        )
                    }
                } header: {
                    Text("接続")
                }

                // ── アプリ情報 ──
                Section {
                    SettingsRow(
                        icon: "info.circle.fill",
                        iconColor: .gray,
                        title: "バージョン",
                        subtitle: appVersion
                    )
                    .listRowSeparator(.hidden)
                } header: {
                    Text("アプリ情報")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // タブを切り替えて戻るたびに最新の設定状態を反映
                isAWSConfigured = AWSNetworkService.shared.isConfigured()
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "v\(version) (\(build))"
    }
}

// MARK: - 汎用設定行コンポーネント

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var badge: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            // アイコン背景
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor)
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            // テキスト
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // バッジ（未設定など警告表示）
            if let badge {
                Text(badge)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.orange))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    SettingsView(
        firestoreService: FirestoreService(),
        childId: "test-child-001"
    )
}
