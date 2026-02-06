# ビルドチェックリスト

## 実装完了したファイル

### ✅ 新規作成ファイル
- [x] `APIModels.swift` - AWS REST API用データモデル
- [x] `AWSNetworkService.swift` - AWS REST API通信サービス
- [x] `PushNotificationHandler.swift` - プッシュ通知ハンドラー
- [x] `BuildTest.swift` - ビルドテスト用（削除可能）
- [x] `AWS_API_INTEGRATION.md` - 統合ガイド

### ✅ 修正済みファイル
- [x] `FirestoreService.swift` - AWS API連携機能追加
- [x] `NRFCloudSettingsView.swift` - AWS API設定UI追加
- [x] `mimamoriGPSApp.swift` - プッシュ通知処理統合

## ビルド前の確認事項

### 1. Xcodeプロジェクトへのファイル追加

以下のファイルがXcodeプロジェクトに追加されているか確認:
```
☐ APIModels.swift
☐ AWSNetworkService.swift
☐ PushNotificationHandler.swift
☐ BuildTest.swift (テスト用、任意)
```

**追加方法:**
1. Xcodeを開く
2. プロジェクトナビゲーターで右クリック → "Add Files to..."
3. 上記ファイルを選択
4. "Copy items if needed" にチェック
5. "Add" をクリック

### 2. 必要なフレームワーク

既存のプロジェクトで使用されているフレームワークがあれば問題なし:
```
✅ Foundation
✅ SwiftUI
✅ FirebaseFirestore
✅ FirebaseMessaging
✅ UserNotifications
✅ CoreLocation
```

### 3. 既存ファイルとの互換性確認

以下のファイルが存在し、正しくインポートできるか確認:
```
✅ SafeZone.swift
✅ BusLocation.swift
✅ ZoneEvent.swift
✅ NRFCloudConfig.swift
```

## ビルド手順

### ステップ 1: クリーンビルド
```
Product → Clean Build Folder (Shift + Cmd + K)
```

### ステップ 2: ビルド
```
Product → Build (Cmd + B)
```

### ステップ 3: エラー確認

#### よくあるビルドエラーと対処法

**エラー1: "Cannot find type 'Location' in scope"**
```
原因: APIModels.swift がプロジェクトに追加されていない
対処: Xcodeプロジェクトに APIModels.swift を追加
```

**エラー2: "Cannot find type 'AWSNetworkService' in scope"**
```
原因: AWSNetworkService.swift がプロジェクトに追加されていない
対処: Xcodeプロジェクトに AWSNetworkService.swift を追加
```

**エラー3: "Cannot find 'PushNotificationHandler' in scope"**
```
原因: PushNotificationHandler.swift がプロジェクトに追加されていない
対処: Xcodeプロジェクトに PushNotificationHandler.swift を追加
```

**エラー4: "Type 'FirestoreService.DataSource' has no member 'awsBackend'"**
```
原因: FirestoreService.swift の変更が反映されていない
対処: FirestoreService.swift を最新版に更新
```

**エラー5: 型の重複エラー**
```
原因: 同じファイルが複数回追加されている
対処: プロジェクトナビゲーターで重複ファイルを削除
```

## ビルド後のテスト

### 1. 設定画面の確認
```
1. アプリを起動
2. 設定アイコンをタップ
3. 「データソース」ピッカーが表示されるか確認
4. 「AWS REST API」を選択
5. AWS設定フィールドが表示されるか確認
```

### 2. データソース切り替えテスト
```swift
// FirestoreService でデータソースを切り替え
FirestoreService.shared.setDataSource(.awsBackend)

// 設定が保存されているか確認
print(FirestoreService.shared.dataSource) // .awsBackend
```

### 3. AWSNetworkService テスト（設定前）
```swift
// 設定前は false を返すはず
print(AWSNetworkService.shared.isConfigured()) // false
```

## トラブルシューティング

### プロジェクトファイルが見つからない場合

1. Finderでプロジェクトフォルダを開く
2. 以下のファイルが存在するか確認:
   ```
   - APIModels.swift
   - AWSNetworkService.swift
   - PushNotificationHandler.swift
   ```
3. 存在する場合は、Xcodeで "Add Files to..." から追加

### ビルドが通らない場合

1. **Clean Build Folder** を実行（Shift + Cmd + K）
2. **Derived Data を削除**:
   ```
   Xcode → Preferences → Locations → Derived Data
   → フォルダを開いて削除
   ```
3. Xcodeを再起動
4. プロジェクトを開き直してビルド

### Swiftバージョンの互換性

このコードは以下のバージョンで動作します:
```
Swift 5.5+ (async/await サポート)
iOS 15.0+
```

プロジェクトの Deployment Target を確認:
```
Project Settings → General → Deployment Info → iOS
→ 15.0 以上に設定
```

## 完了チェック

ビルドが成功したら、以下を確認:

- [ ] ビルドエラーなし（0 errors）
- [ ] 警告の確認（あれば対処）
- [ ] アプリが起動する
- [ ] 設定画面が正常に表示される
- [ ] データソース選択ができる
- [ ] クラッシュしない

## 次のステップ

ビルドが成功したら:

1. **AWS側の実装を待つ**
   - AWS APIのエンドポイントが実装されるのを待つ

2. **設定情報を入力**
   - Base URL
   - API Key
   - Device ID

3. **連携テスト**
   - `GET /devices` を呼び出してレスポンスを確認
   - セーフゾーン取得をテスト
   - プッシュ通知をテスト

## サポート

ビルドエラーが解決しない場合は、以下の情報を共有してください:
- エラーメッセージの全文
- エラーが発生しているファイル名と行番号
- Xcodeのバージョン
- macOSのバージョン
