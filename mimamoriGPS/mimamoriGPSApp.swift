//
//  mimamoriGPSApp.swift
//  mimamoriGPS
//
//  Created by 木下美樹 on 2025/10/09.
//



import SwiftUI
import FirebaseCore
import FirebaseMessaging
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebase初期化
        FirebaseApp.configure()
        print("✅ Firebase initialized")
        
        // 通知センターのデリゲート設定
        UNUserNotificationCenter.current().delegate = self
        
        // Messagingのデリゲート設定
        Messaging.messaging().delegate = self
        
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
        print("✅ APNsトークン登録成功")
        
        // FCMにAPNsトークンを設定
        Messaging.messaging().apnsToken = deviceToken
    }
    
    // MARK: - APNsトークン登録失敗
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNsトークン登録失敗: \(error.localizedDescription)")
    }
    
    // MARK: - MessagingDelegate - FCMトークン受信
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("❌ FCMトークンが取得できませんでした")
            return
        }
        
        print("✅ FCMトークン取得成功: \(fcmToken)")
        
        // Firestoreに保存
        saveFCMTokenToFirestore(fcmToken: fcmToken)
    }
    
    // MARK: - FCMトークンをFirestoreに保存
    
    private func saveFCMTokenToFirestore(fcmToken: String) {
        FirestoreService.shared.saveFCMToken(fcmToken, forUserId: "test-child-001")
        print("✅ FCMトークン保存を開始しました")
    }
    
    // MARK: - UNUserNotificationCenterDelegate - フォアグラウンド通知受信
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        let userInfo = notification.request.content.userInfo
        print("📬 フォアグラウンド通知受信: \(userInfo)")
        
        // アプリ起動中でも通知を表示
        completionHandler([[.banner, .sound, .badge]])
    }
    
    // MARK: - UNUserNotificationCenterDelegate - 通知タップ時
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        print("👆 通知タップ: \(userInfo)")
        
        // 通知タップ時の処理
        handleNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
    
    // MARK: - 通知タップ時の処理
    
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        if let notificationType = userInfo["type"] as? String {
            print("📱 通知タイプ: \(notificationType)")
            
            switch notificationType {
            case "zone_enter":
                print("🟢 セーフゾーン入場通知")
            case "zone_exit":
                print("🔴 セーフゾーン退場通知")
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
