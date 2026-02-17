//
//  NRFCloudSettingsView.swift
//  mimamoriGPS
//
//  nRF Cloud API設定画面
//

import SwiftUI

struct NRFCloudSettingsView: View {
    @State private var deviceID: String = UserDefaults.standard.string(forKey: "nrf_device_id") ?? ""
    @State private var deviceName: String = UserDefaults.standard.string(forKey: "device_display_name") ?? "デバイス"
    @State private var showSaveAlert = false
    @State private var showResetAlert = false
    
    // AWS API設定
    @State private var awsBaseURL: String = UserDefaults.standard.string(forKey: "aws_base_url") ?? ""
    @State private var awsAPIKey: String = UserDefaults.standard.string(forKey: "aws_api_key") ?? ""
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            // 設定状態セクション
            Section {
                HStack {
                    Image(systemName: configurationStatus.isConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(configurationStatus.isConfigured ? .green : .orange)
                    Text(configurationStatus.message)
                        .fontWeight(.semibold)
                }
            } header: {
                Text("設定状態")
            }

            // AWS API設定セクション
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Base URL")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("https://xxx.execute-api.ap-northeast-1.amazonaws.com/dev", text: $awsBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("API Key")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    SecureField("API Keyを入力", text: $awsAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                        .autocapitalization(.none)
                }
            } header: {
                Text("AWS REST API設定")
            } footer: {
                Text("AWS API GatewayのエンドポイントURLとAPI Keyを入力してください。")
            }

            // Device ID設定
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("表示名")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("太郎", text: $deviceName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Device ID")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("nrf-352656100123456", text: $deviceID)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                }
            } header: {
                Text("デバイス設定")
            } footer: {
                Text("表示名: 地図上に表示される名前\nDevice ID: nRF Cloudデバイスの識別子（形式: nrf-{IMEI 15桁}）")
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
                .disabled(!canSave)

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

            // 設定手順セクション
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    awsAPIInstructions
                }
            } header: {
                Text("設定手順")
            }
        }
        .navigationTitle("AWS API設定")
        .navigationBarTitleDisplayMode(.inline)
        .alert("設定を保存しました", isPresented: $showSaveAlert) {
            Button("OK") { }
        } message: {
            Text("AWS REST APIの設定が完了しました。")
        }
        .alert("設定をリセットしますか?", isPresented: $showResetAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("リセット", role: .destructive) {
                resetConfiguration()
            }
        } message: {
            Text("保存された設定がすべて削除されます。")
        }
    }
    
    // MARK: - Computed Properties
    
    private var configurationStatus: (isConfigured: Bool, message: String) {
        let configured = !awsBaseURL.isEmpty && !awsAPIKey.isEmpty && !deviceID.isEmpty
        return (configured, configured ? "AWS API設定完了" : "AWS API未設定")
    }
    
    private var canSave: Bool {
        return !awsBaseURL.isEmpty && !awsAPIKey.isEmpty && !deviceID.isEmpty
    }
    
    // MARK: - Instruction Views
    
    private var awsAPIInstructions: some View {
        Group {
            instructionRow(
                number: "1",
                title: "AWS API Gatewayの設定",
                description: "AWSコンソールからAPI GatewayのエンドポイントURLを確認"
            )
            
            Divider()
            
            instructionRow(
                number: "2",
                title: "API Keyを取得",
                description: "API Gateway → APIキー → 使用する APIキーの値をコピー"
            )
            
            Divider()
            
            instructionRow(
                number: "3",
                title: "Device IDを確認",
                description: "nRF CloudのデバイスID（形式: nrf-{IMEI}）を確認"
            )
            
            Divider()
            
            instructionRow(
                number: "4",
                title: "設定を保存",
                description: "Base URL、API Key、Device IDを入力して保存"
            )
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
        // AWS API設定を保存
        UserDefaults.standard.set(awsBaseURL, forKey: "aws_base_url")
        UserDefaults.standard.set(awsAPIKey, forKey: "aws_api_key")
        UserDefaults.standard.set(deviceID, forKey: "nrf_device_id")
        UserDefaults.standard.set(deviceName, forKey: "device_display_name")
        
        // DataServiceのdeviceIdを更新
        DataService.shared.deviceId = deviceID
        
        print("✅ AWS API設定保存完了")
        print("   Base URL: \(awsBaseURL)")
        print("   Device ID: \(deviceID)")
        print("   表示名: \(deviceName)")
        
        showSaveAlert = true
    }
    
    private func resetConfiguration() {
        // すべての設定をリセット
        UserDefaults.standard.removeObject(forKey: "aws_base_url")
        UserDefaults.standard.removeObject(forKey: "aws_api_key")
        UserDefaults.standard.removeObject(forKey: "nrf_device_id")
        UserDefaults.standard.removeObject(forKey: "device_display_name")
        
        // UIをリセット
        awsBaseURL = ""
        awsAPIKey = ""
        deviceID = ""
        deviceName = "デバイス"
        
        print("🗑️ AWS API設定リセット完了")
    }
}

#Preview {
    NavigationView {
        NRFCloudSettingsView()
    }
}
