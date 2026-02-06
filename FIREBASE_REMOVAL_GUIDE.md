# Firebase完全削除ガイド

## 🔥 Firebase削除完了

GoogleのFirebaseサービスを完全に削除し、すべてAWS REST APIに置き換えました。

## 📝 変更内容

### ✅ 削除・置き換えしたファイル

| ファイル | 変更内容 |
|---------|---------|
| `mimamoriGPSApp.swift` | Firebase/FCM削除、APNs直接接続に変更 |
| `SafeZone.swift` | Firebase Firestore削除、シンプルなデータモデルに |
| `NRFCloudSettingsView.swift` | データソース選択削除、AWS API専用UIに |
| `FirestoreService.swift` | **削除予定** - DataService.swiftで完全置き換え |

### 🆕 新規作成ファイル

| ファイル | 説明 |
|---------|------|
| `DataService.swift` | AWS REST API専用データサービス（FirestoreServiceの完全置き換え） |

### ❌ 削除されたFirebase機能

- ✅ `FirebaseCore` - 完全削除
- ✅ `FirebaseFirestore` - 完全削除
- ✅ `FirebaseMessaging (FCM)` - 完全削除
- ✅ Firebaseからのデータ取得 - AWS REST APIに置き換え
- ✅ FCMトークン管理 - APNsトークン直接管理に置き換え
- ✅ FirestoreのGeoPoint - 独自のCoordinate型に置き換え
- ✅ FirestoreのTimestamp - Date型に置き換え

## 🚀 移行手順

### ステップ1: Firebaseパッケージをプロジェクトから削除

1. Xcodeを開く
2. **Project Navigator** → プロジェクト名をクリック
3. **Package Dependencies** タブ
4. 以下のパッケージを削除:
   ```
   - Firebase
   - FirebaseFirestore
   - FirebaseMessaging
   ```

### ステップ2: `GoogleService-Info.plist` を削除

1. **Project Navigator** で `GoogleService-Info.plist` を探す
2. 右クリック → **Delete**
3. "Move to Trash" を選択

### ステップ3: 新規ファイルをプロジェクトに追加

以下のファイルをXcodeプロジェクトに追加:
```
☐ DataService.swift
☐ APIModels.swift (既に追加済みの場合はスキップ)
☐ AWSNetworkService.swift (既に追加済みの場合はスキップ)
☐ PushNotificationHandler.swift (既に追加済みの場合はスキップ)
```

### ステップ4: 古いファイルの削除（任意）

以下のファイルは使用されなくなりました:
```
☐ FirestoreService.swift - DataService.swiftで完全置き換え
☐ BusLocation.swift - 公共交通DB用、不要なら削除
☐ ZoneEvent.swift - Firebase用、不要なら削除
```

**注意**: これらのファイルは他のUIから参照されている可能性があるため、削除前に確認してください。

### ステップ5: ビルド設定の確認

1. **Build Settings** を開く
2. **Other Linker Flags** からFirebase関連のフラグを削除
3. **Framework Search Paths** からFirebase関連のパスを削除

### ステップ6: Info.plistの確認

`Info.plist` からFirebase関連の設定を削除:
```xml
<!-- 削除する項目 -->
<key>FirebaseAppDelegateProxyEnabled</key>
<key>FirebaseAutomaticScreenReportingEnabled</key>
```

## 🔧 コードの変更点

### 通知システム

**変更前 (Firebase/FCM):**
```swift
import FirebaseMessaging

// FCMトークンを取得
Messaging.messaging().token { token, error in
    // FCMトークンをサーバーに送信
}
```

**変更後 (APNs直接):**
```swift
// APNsトークンを直接取得
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    // APNsトークンをAWSに送信
    saveAPNsTokenToAWS(tokenString)
}
```

### データ取得

**変更前 (Firestore):**
```swift
import FirebaseFirestore

FirestoreService.shared.startListening()
```

**変更後 (AWS REST API):**
```swift
DataService.shared.startListening()
```

### セーフゾーン管理

**変更前 (Firestore):**
```swift
struct SafeZone {
    var center: GeoPoint  // Firebase型
    @ServerTimestamp var createdAt: Timestamp?
}
```

**変更後 (AWS API):**
```swift
struct SafeZone {
    var centerLat: Double
    var centerLon: Double
    var createdAt: Date
}
```

## 📱 APNs設定（AWS側で必要）

Firebaseを削除したため、APNsの設定をAWS SNSで行う必要があります:

### AWS側の設定

1. **APNs証明書/キーをAWS SNSにアップロード**
   ```
   AWS Console → SNS → Mobile → Push notifications
   → Create platform application
   → iOS (APNs)
   ```

2. **Platform Application ARNを取得**
   ```
   例: arn:aws:sns:ap-northeast-1:123456789012:app/APNS/MyApp
   ```

3. **APNsトークン登録エンドポイントを実装**
   ```
   POST /devices/{deviceId}/apns-token
   {
     "token": "abc123..."
   }
   ```

## 🧪 テスト方法

### 1. ビルドエラーの確認

```bash
# クリーンビルド
Product → Clean Build Folder (Shift + Cmd + K)

# ビルド
Product → Build (Cmd + B)
```

**期待される結果**: Firebaseインポートエラーがないこと

### 2. アプリ起動テスト

```swift
// アプリ起動時のログ確認
✅ アプリ起動 - AWS REST API専用モード
✅ 通知権限が許可されました
✅ APNsトークン登録成功
```

### 3. データ取得テスト（AWS実装完了後）

```swift
// DataServiceを使用
DataService.shared.deviceId = "nrf-352656100123456"
DataService.shared.startListening()

// ログ確認
🚀 AWS APIからのデータ取得開始
🌐 AWS API: デバイスデータ取得中...
✅ 位置情報取得成功: (35.681236, 139.767125)
```

### 4. プッシュ通知テスト

AWS SNS経由でAPNsプッシュ通知を送信:
```json
{
  "aps": {
    "alert": {
      "title": "セーフゾーンアラート",
      "body": "デバイスがセーフゾーンから離れました"
    },
    "sound": "default"
  },
  "data": {
    "type": "ZONE_EXIT",
    "deviceId": "nrf-352656100123456",
    ...
  }
}
```

## 📊 Firebase vs AWS 比較

| 項目 | Firebase | AWS |
|-----|----------|-----|
| データベース | Firestore | DynamoDB (AWS側) |
| プッシュ通知 | FCM | APNs直接 + SNS |
| 認証 | Firebase Auth | API Key (API Gateway) |
| リアルタイム | Firestore Listener | ポーリング (60秒) |
| コスト | 従量課金 | 従量課金 |
| ベンダーロックイン | Google | AWS |

## ⚠️ 注意事項

### 既存ユーザーへの影響

Firebase削除により、以下の影響があります:

1. **Firestoreに保存されていたデータ**
   - セーフゾーン設定
   - 履歴データ
   - イベントログ
   
   → AWS DynamoDBに移行する必要があります

2. **FCMトークン**
   - 既存のFCMトークンは無効になります
   - アプリ再起動時に新しいAPNsトークンが登録されます

3. **プッシュ通知**
   - FCM経由の通知は届かなくなります
   - AWS SNS経由のAPNs通知に切り替わります

### データ移行スクリプト（必要な場合）

Firestoreのデータをエクスポートし、AWS DynamoDBにインポートするスクリプトが必要な場合は、別途作成してください。

## ✅ 完了チェックリスト

- [ ] Firebaseパッケージを削除
- [ ] `GoogleService-Info.plist` を削除
- [ ] `DataService.swift` を追加
- [ ] ビルドエラーなし
- [ ] アプリが起動する
- [ ] APNsトークンが取得できる
- [ ] AWS API設定ができる
- [ ] データ取得が動作する（AWS実装完了後）
- [ ] プッシュ通知が届く（AWS実装完了後）

## 🎉 メリット

### Firebase削除により得られるメリット

1. **ベンダーロックイン回避**
   - Googleサービスへの依存を完全排除
   - AWS単一ベンダーに統一

2. **シンプルなアーキテクチャ**
   - REST APIのみでシンプル
   - Firebase SDKの複雑さを排除

3. **コスト最適化**
   - 必要なサービスのみを使用
   - FirebaseとAWSの二重課金を回避

4. **セキュリティ**
   - API Key認証でシンプル
   - AWS IAMでアクセス制御

5. **カスタマイズ性**
   - AWS Lambdaで自由に実装
   - ビジネスロジックを完全制御

---

**Firebase完全削除完了日**: 2026-02-05  
**新アーキテクチャ**: AWS REST API専用  
**最小対応OS**: iOS 15.0+
