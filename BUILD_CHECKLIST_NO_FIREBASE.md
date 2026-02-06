# ビルドチェックリスト（Firebase削除版）

## 🔥 Firebase完全削除 - AWS専用版

このプロジェクトは**Firebase/Googleサービスを完全に削除**し、**AWS REST API専用**に再構築されています。

## 📦 必要なファイル

### ✅ 新規作成ファイル（必須）

以下のファイルをXcodeプロジェクトに追加してください:

```
☐ APIModels.swift           - AWS API データモデル
☐ AWSNetworkService.swift   - AWS API通信サービス
☐ PushNotificationHandler.swift - プッシュ通知ハンドラー
☐ DataService.swift         - データ管理サービス（FirestoreService置き換え）
```

### ✅ 修正済みファイル

以下のファイルはFirebase依存が削除されています:

```
☑ mimamoriGPSApp.swift      - FCM削除、APNs直接接続
☑ SafeZone.swift            - Firestore削除、シンプルなモデル
☑ NRFCloudSettingsView.swift - データソース選択削除、AWS専用UI
```

### ❌ 削除推奨ファイル（任意）

以下のファイルは不要になりました:

```
☐ FirestoreService.swift    - DataService.swiftで完全置き換え
☐ BusLocation.swift         - 公共交通DB用（不要なら削除）
☐ ZoneEvent.swift           - Firebase用（不要なら削除）
```

**注意**: これらのファイルが他のUIから参照されていないか確認してから削除してください。

## 🚀 ビルド手順

### ステップ1: Firebaseパッケージを削除

1. Xcodeを開く
2. **Project Navigator** → プロジェクト名をクリック
3. **Package Dependencies** タブ
4. 以下を削除:
   ```
   ✓ Firebase
   ✓ FirebaseFirestore
   ✓ FirebaseMessaging
   ```

**削除方法**:
- パッケージを選択 → 「-」ボタンをクリック
- または右クリック → "Delete"

### ステップ2: GoogleService-Info.plist を削除

1. **Project Navigator** で `GoogleService-Info.plist` を探す
2. 右クリック → **Delete**
3. "Move to Trash" を選択

### ステップ3: 新規ファイルを追加

1. **Project Navigator** でプロジェクト名を右クリック
2. **"Add Files to..."** を選択
3. 以下の4ファイルを選択:
   ```
   ✓ APIModels.swift
   ✓ AWSNetworkService.swift
   ✓ PushNotificationHandler.swift
   ✓ DataService.swift
   ```
4. **"Copy items if needed"** にチェック
5. ターゲットが選択されているか確認
6. **"Add"** をクリック

### ステップ4: クリーンビルド

```
Product → Clean Build Folder (Shift + Cmd + K)
```

### ステップ5: ビルド実行

```
Product → Build (Cmd + B)
```

## ⚠️ 予想されるビルドエラーと対処法

### エラー1: "No such module 'FirebaseCore'"

```
原因: Firebaseパッケージが残っている
対処: ステップ1を実行してFirebaseパッケージを完全に削除
```

### エラー2: "Cannot find type 'GeoPoint' in scope"

```
原因: SafeZone.swiftが古いバージョンのまま
対処: SafeZone.swiftを最新版に更新（Firebase削除版）
```

### エラー3: "Cannot find 'FirestoreService' in scope"

```
原因: UIコードがまだFirestoreServiceを参照している
対処:
1. エラー箇所を確認
2. FirestoreService → DataService に置き換え
3. または該当UIファイルを更新
```

### エラー4: "Cannot find type 'Location' in scope"

```
原因: APIModels.swiftがプロジェクトに追加されていない
対処: ステップ3を実行してAPIModels.swiftを追加
```

### エラー5: "'DataService' is not a member type of 'FirestoreService'"

```
原因: 古いコードが残っている
対処:
FirestoreService.shared → DataService.shared に置き換え
```

## 🧪 ビルド成功後のテスト

### 1. アプリ起動確認

アプリを起動して、以下のログが出力されることを確認:

```
✅ アプリ起動 - AWS REST API専用モード
✅ 通知権限が許可されました
✅ APNsトークン登録成功
📱 Token: abc123...
```

### 2. 設定画面の確認

1. 設定アイコンをタップ
2. 以下が表示されることを確認:
   ```
   ✓ AWS REST API設定
   ✓ Base URL入力フィールド
   ✓ API Key入力フィールド
   ✓ Device ID入力フィールド
   ✓ 設定を保存ボタン
   ```

### 3. 設定保存テスト

1. 以下を入力:
   ```
   Base URL: https://test.execute-api.ap-northeast-1.amazonaws.com/dev
   API Key: test-key-123
   Device ID: nrf-352656100123456
   ```
2. 「設定を保存」をタップ
3. "設定を保存しました" アラートが表示されることを確認

### 4. DataService動作確認

```swift
// AWS API設定後にテスト
DataService.shared.deviceId = "nrf-352656100123456"
DataService.shared.startListening()

// 期待されるログ:
🚀 AWS APIからのデータ取得開始
🌐 AWS API: デバイスデータ取得中...
```

**注意**: AWS側の実装が完了していない場合、エラーが返されますが正常です。

## 📋 完了チェックリスト

### Firebaseパッケージ削除

- [ ] Firebase SDKを削除
- [ ] FirebaseFirestoreを削除
- [ ] FirebaseMessagingを削除
- [ ] GoogleService-Info.plistを削除

### 新規ファイル追加

- [ ] APIModels.swiftを追加
- [ ] AWSNetworkService.swiftを追加
- [ ] PushNotificationHandler.swiftを追加
- [ ] DataService.swiftを追加

### ビルド確認

- [ ] ビルドエラーなし（0 errors）
- [ ] Firebase関連の警告なし
- [ ] アプリが起動する
- [ ] クラッシュしない

### 機能確認

- [ ] 設定画面が表示される
- [ ] AWS API設定が保存できる
- [ ] APNsトークンが取得できる
- [ ] エラーメッセージが適切に表示される

## 🔧 トラブルシューティング

### ビルドが通らない

1. **Derived Dataを削除**
   ```
   Xcode → Preferences → Locations → Derived Data
   → フォルダを開いて削除
   ```

2. **Xcodeを再起動**

3. **プロジェクトを開き直してビルド**

### Firebaseインポートエラーが消えない

1. **Build Settings** を確認
2. **Other Linker Flags** からFirebase関連のフラグを削除
3. **Framework Search Paths** からFirebase関連のパスを削除

### APNsトークンが取得できない

1. **Capabilities** を確認
   ```
   Project Settings → Signing & Capabilities
   → Push Notifications が有効か確認
   ```

2. **Background Modes** を確認
   ```
   → Remote notifications にチェックが入っているか確認
   ```

## 📚 関連ドキュメント

詳細情報は以下のドキュメントを参照:

- **`FIREBASE_REMOVAL_GUIDE.md`** - Firebase削除の詳細ガイド
- **`AWS_API_INTEGRATION.md`** - AWS API統合ガイド
- **`README_AWS_INTEGRATION.md`** - 実装サマリー
- **`api_specification.md`** - API仕様書

## 🎯 次のステップ

ビルドが成功したら:

1. **AWS側の実装完了を待つ**
   - Lambda関数
   - DynamoDB
   - API Gateway
   - SNS → APNs連携

2. **AWS API設定を入力**
   - Base URL
   - API Key
   - Device ID

3. **連携テスト**
   - データ取得
   - セーフゾーン管理
   - プッシュ通知

4. **本番デプロイ**
   - APNs Production証明書の設定
   - AWS本番環境への切り替え

---

**Firebase削除完了日**: 2026-02-05  
**新アーキテクチャ**: AWS REST API専用  
**プッシュ通知**: APNs直接 + AWS SNS  
**最小対応OS**: iOS 15.0+
