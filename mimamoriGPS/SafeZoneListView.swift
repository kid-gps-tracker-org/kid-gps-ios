//
//  SafeZoneListView.swift
//  mimamoriGPS
//
//  セーフゾーン一覧画面
//

import SwiftUI

struct SafeZoneListView: View {
    // MARK: - Properties
    @StateObject private var firestoreService = FirestoreService()
    @State private var showingAddSheet = false
    @State private var selectedZone: SafeZone?
    
    let childId: String
    
    // MARK: - Body
    var body: some View {
        let _ = print("🔄 SafeZoneListView 再描画: \(firestoreService.safeZones.count)件")
        
        NavigationView {
            Group {
                if firestoreService.safeZones.isEmpty {
                    // 空の状態
                    emptyStateView
                } else {
                    // リスト表示
                    safeZoneList
                }
            }
            .navigationTitle("セーフゾーン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                SafeZoneEditView(
                    firestoreService: firestoreService,
                    childId: childId,
                    safeZone: nil,
                    initialLocation: firestoreService.currentBusLocation?.coordinate
                )
            }
            .sheet(item: $selectedZone) { zone in
                SafeZoneEditView(
                    firestoreService: firestoreService,
                    childId: childId,
                    safeZone: zone,
                    initialLocation: nil
                )
            }
            .task {
                print("🚀 SafeZoneListView.task 開始: childId=\(childId)")
                
                // バス位置の監視開始
                firestoreService.startListening()
                print("🎯 バス位置監視開始")
                
                // セーフゾーンの監視開始
                firestoreService.startListeningSafeZones(childId: childId)
                print("🎯 セーフゾーン監視開始")
            }
        }
    }
    
    // MARK: - Subviews
    
    /// セーフゾーンリスト
    private var safeZoneList: some View {
        List {
            ForEach(firestoreService.safeZones) { zone in
                SafeZoneRow(zone: zone)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedZone = zone
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteSafeZone(zone)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    /// 空の状態ビュー
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("セーフゾーンがありません")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("右上の＋ボタンから\nセーフゾーンを追加できます")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    /// 追加ボタン
    private var addButton: some View {
        Button(action: {
            // 10個制限チェック
            if firestoreService.safeZones.count >= 10 {
                // TODO: アラート表示
                print("⚠️ セーフゾーンは10個まで")
            } else {
                showingAddSheet = true
            }
        }) {
            Image(systemName: "plus")
        }
        .disabled(firestoreService.safeZones.count >= 10)
    }
    
    // MARK: - Methods
    
    /// セーフゾーンを削除
    private func deleteSafeZone(_ zone: SafeZone) {
        guard let id = zone.id else { return }
        
        firestoreService.deleteSafeZone(id) { result in
            switch result {
            case .success:
                print("✅ 削除成功")
            case .failure(let error):
                print("❌ 削除失敗: \(error)")
            }
        }
    }
}

// MARK: - SafeZoneRow

struct SafeZoneRow: View {
    let zone: SafeZone
    
    var body: some View {
        HStack(spacing: 12) {
            // カラーインジケーター
            Circle()
                .fill(Color(zone.uiColor))
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                // ゾーン名
                Text(zone.name)
                    .font(.system(size: 17, weight: .medium))
                
                // 半径
                Text("半径 \(Int(zone.radius))m")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 編集アイコン
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

struct SafeZoneListView_Previews: PreviewProvider {
    static var previews: some View {
        SafeZoneListView(childId: "test-child-001")
    }
}
