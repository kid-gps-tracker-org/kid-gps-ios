//
//  NRFCloudSettingsView.swift
//  mimamoriGPS
//
//  nRF Cloud API設定画面
//

import SwiftUI

struct NRFCloudSettingsView: View {
    @State private var apiKey: String = NRFCloudConfig.apiKey
    @State private var deviceID: String = NRFCloudConfig.deviceID
    @State private var showSaveAlert = false
    @State private var showResetAlert = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // 設定状態セクション
                Section {
                    HStack {
                        Image(systemName: NRFCloudConfig.isConfigured() ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(NRFCloudConfig.isConfigured() ? .green : .orange)
                        
                        Text(NRFCloudConfig.isConfigured() ? "設定完了" : "未設定")
                            .fontWeight(.semibold)
                    }
                } header: {
                    Text("設定状態")
                }
                
                // API設定セクション
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        SecureField("API Keyを入力", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .autocapitalization(.none)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Device ID")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Device IDを入力", text: $deviceID)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                    }
                } header: {
                    Text("nRF Cloud API設定")
                } footer: {
                    Text("nRF Cloud PortalからAPI KeyとDevice IDを取得して入力してください。")
                }
                
                // 接続情報セクション
                Section {
                    LabeledContent("API Base URL") {
                        Text(NRFCloudConfig.baseURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("接続情報")
                }
                
                // アクションセクション
                Section {
                    Button {
                        saveConfiguration()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("設定を保存")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(apiKey.isEmpty || deviceID.isEmpty)
                    
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("設定をリセット")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                
                // 使用方法セクション
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        instructionRow(
                            number: "1",
                            title: "nRF Cloud Portalにアクセス",
                            description: "https://nrfcloud.com にログイン"
                        )
                        
                        Divider()
                        
                        instructionRow(
                            number: "2",
                            title: "API Keyを取得",
                            description: "Account Settings → API Keys → Create API Key"
                        )
                        
                        Divider()
                        
                        instructionRow(
                            number: "3",
                            title: "Device IDを確認",
                            description: "Devices → デバイス一覧からIDをコピー"
                        )
                        
                        Divider()
                        
                        instructionRow(
                            number: "4",
                            title: "設定を保存",
                            description: "上記フォームに入力して保存ボタンをタップ"
                        )
                    }
                } header: {
                    Text("設定手順")
                }
            }
            .navigationTitle("nRF Cloud設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("設定を保存しました", isPresented: $showSaveAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("nRF Cloudの設定が完了しました。")
            }
            .alert("設定をリセットしますか?", isPresented: $showResetAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("リセット", role: .destructive) {
                    resetConfiguration()
                }
            } message: {
                Text("保存されたAPI KeyとDevice IDが削除されます。")
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func instructionRow(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveConfiguration() {
        NRFCloudConfig.saveAPIKey(apiKey)
        NRFCloudConfig.saveDeviceID(deviceID)
        showSaveAlert = true
    }
    
    private func resetConfiguration() {
        NRFCloudConfig.resetConfig()
        apiKey = ""
        deviceID = ""
    }
}

#Preview {
    NRFCloudSettingsView()
}
