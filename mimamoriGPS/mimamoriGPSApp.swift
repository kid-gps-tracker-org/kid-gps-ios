//
//  mimamoriGPSApp.swift
//  mimamoriGPS
//
//  AWS REST API専用 - Firebase完全削除版
//

import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        print("✅ アプリ起動 - AWS REST API専用モード")
        
        // 通知センターのデリゲート設定
        UNUserNotificationCenter.current().delegate = self
        
        // 通知権限をリクエスト
        requestNotificationPermission(application: application)
        
        // APNsトークン登録
        application.registerForRemoteNotifications()
        
        return true
    }
    
    // MARK: - 通知権限リクエスト
    
    private func requestNotificationPermission(application: UIApplication) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("❌ 通知権限エラー: \(error.localizedDescription)")
                    return
                }
                
                if granted {
                    print("✅ 通知権限が許可されました")
                } else {
                    print("⚠️ 通知権限が拒否されました")
                }
            }
        )
    }
    
    // MARK: - APNsトークン登録成功
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // APNsトークンを16進数文字列に変換
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ APNsトークン登録成功")
        print("📱 Token: \(tokenString)")
        
        // APNsトークンをAWS SNSに登録（AWS実装完了後に使用）
        saveAPNsTokenToAWS(tokenString)
    }
    
    // MARK: - APNsトークン登録失敗
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNsトークン登録失敗: \(error.localizedDescription)")
    }
    
    // MARK: - バックグラウンド / キルド状態でのリモート通知受信
    // Info.plist の UIBackgroundModes に "remote-notification" が必要

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📬 バックグラウンド通知受信")

        PushNotificationHandler.shared.handleNotification(userInfo)

        completionHandler(.newData)
    }
    
    // MARK: - APNsトークンをAWSに保存
    
    private func saveAPNsTokenToAWS(_ token: String) {
        // UserDefaultsに一時保存
        UserDefaults.standard.set(token, forKey: "apns_device_token")
        print("💾 APNsトークンを保存: \(token.prefix(20))...")
        
        // AWS APIを使用してトークンを登録（今後実装）
        Task {
            do {
                guard AWSNetworkService.shared.isConfigured() else {
                    print("⚠️ AWS API未設定のため、トークン登録をスキップ")
                    return
                }
                
                // TODO: AWS側でAPNsトークン登録エンドポイントが実装されたら有効化
                // let deviceId = UserDefaults.standard.string(forKey: "nrf_device_id") ?? ""
                // try await AWSNetworkService.shared.registerAPNsToken(deviceId: deviceId, token: token)
                
                print("✅ APNsトークン登録準備完了（AWS実装待ち）")
            } catch {
                print("❌ APNsトークン登録エラー: \(error)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate - フォアグラウンド通知受信
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        let userInfo = notification.request.content.userInfo
        print("📬 フォアグラウンド通知受信: \(userInfo)")
        
        // AWS API プッシュ通知を処理
        PushNotificationHandler.shared.handleNotification(userInfo)
        
        // アプリ起動中でも通知を表示
        completionHandler([[.banner, .sound, .badge]])
    }
    
    // MARK: - UNUserNotificationCenterDelegate - 通知タップ時
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        print("👆 通知タップ: \(userInfo)")
        
        // AWS API プッシュ通知を処理
        PushNotificationHandler.shared.handleNotification(userInfo)
        
        // 通知タップ時の処理
        handleNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
    
    // MARK: - 通知タップ時の処理
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // dataフィールドからタイプを取得
        if let data = userInfo["data"] as? [String: Any],
           let notificationType = data["type"] as? String {
            print("📱 通知タイプ: \(notificationType)")
            
            switch notificationType {
            case "ZONE_ENTER":
                print("🟢 セーフゾーン帰還通知")
                // イベント履歴タブへ遷移するよう通知
                NotificationCenter.default.post(name: .navigateToZoneHistory, object: nil)
            case "ZONE_EXIT":
                print("🔴 セーフゾーン離脱通知")
                // イベント履歴タブへ遷移するよう通知
                NotificationCenter.default.post(name: .navigateToZoneHistory, object: nil)
            default:
                print("📨 その他の通知")
            }
        }
    }
}

@main
struct mimamoriGPSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
// MARK: - Notification Name Extension

extension Notification.Name {
    /// 通知タップ時にイベント履歴タブへ遷移を促す通知
    static let navigateToZoneHistory = Notification.Name("navigateToZoneHistory")
}

