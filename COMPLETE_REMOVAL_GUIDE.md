# Firebase・公共交通DB 完全削除ガイド

## 🔥 Google & 公共交通DB 完全削除完了

以下のサービスを完全に削除し、**AWS REST API専用**に再構築しました:

- ❌ **Firebase (Google)** - Firestore、FCM、Auth
- ❌ **公共交通オープンデータ** - バス位置情報DB

## 📝 削除したもの

### Firebase関連
- ✅ FirebaseCore
- ✅ FirebaseFirestore
- ✅ FirebaseMessaging (FCM)
- ✅ Firestore GeoPoint → シンプルなCoordinate型
- ✅ Firestore Timestamp → Date型
- ✅ FCMトークン → APNsトークン直接管理

### 公共交通DB関連
- ✅ BusLocation（バス位置情報モデル）
- ✅ 公共交通オープンデータからのデータ取得
- ✅ Firestoreの`bus_locations`コレクション
- ✅ バスルート情報
- ✅ バス事業者情報

## 📁 ファイルの変更

### 🆕 新規作成

| ファイル | 説明 |
|---------|------|
| `DataService.swift` | AWS API専用データサービス |
| `DeviceLocation.swift` | デバイス位置情報モデル（BusLocation置き換え） |
| `APIModels.swift` | AWS API データ型 |
| `AWSNetworkService.swift` | AWS API通信 |
| `PushNotificationHandler.swift` | APNsプッシュ通知 |

### 🔧 置き換え・修正

| 元ファイル | 新ファイル/変更内容 |
|----------|------------------|
| `BusLocation.swift` | `DeviceLocation.swift` に置き換え |
| `FirestoreService.swift` | `DataService.swift` に置き換え |
| `SafeZone.swift` | Firebase依存削除、シンプル化 |
| `mimamoriGPSApp.swift` | FCM削除、APNs直接接続 |
| `NRFCloudSettingsView.swift` | データソース選択削除、AWS専用UI |

### ❌ 完全削除推奨

| ファイル | 理由 |
|---------|------|
| `FirestoreService.swift` | DataService.swiftで完全置き換え |
| `ZoneEvent.swift` | Firebase用、不要 |

## 🚀 移行手順

### ステップ1: Firebaseパッケージを削除

```
Xcode → Project Settings → Package Dependencies
以下を削除:
  - Firebase
  - FirebaseFirestore
  - FirebaseMessaging
```

### ステップ2: 不要ファイルを削除

```
GoogleService-Info.plist → 削除
FirestoreService.swift → 削除
ZoneEvent.swift → 削除（任意）
```

### ステップ3: 新規ファイルを追加

Xcodeプロジェクトに以下を追加:

```
☐ DataService.swift
☐ DeviceLocation.swift
☐ APIModels.swift
☐ AWSNetworkService.swift
☐ PushNotificationHandler.swift
☐ SafeZone.swift（上書き）
☐ mimamoriGPSApp.swift（上書き）
☐ NRFCloudSettingsView.swift（上書き）
```

### ステップ4: ビルド

```
Product → Clean Build Folder (Shift + Cmd + K)
Product → Build (Cmd + B)
```

## 📊 データモデルの変更

### BusLocation → DeviceLocation

**変更前 (BusLocation):**
```swift
struct BusLocation {
    @DocumentID var id: String?
    let timestamp: Timestamp  // Firestore型
    let speed: Double?
    let busOperator: String?
    let busRoute: String?
}
```

**変更後 (DeviceLocation):**
```swift
struct DeviceLocation {
    let id: String
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let source: LocationSource  // GNSS / GROUND_FIX
    let timestamp: Date
}
```

### 主な違い

| 項目 | BusLocation | DeviceLocation |
|-----|------------|----------------|
| データソース | 公共交通オープンデータ | AWS REST API (nRF Cloud) |
| 速度情報 | ✅ あり | ❌ なし |
| バス情報 | ✅ あり | ❌ なし |
| 測位方式 | ❌ なし | ✅ あり (GNSS/GROUND_FIX) |
| 精度情報 | ❌ なし | ✅ あり (meters) |
| 目的 | バス追跡 | デバイス追跡 |

### マーカー色の変更

**変更前:**
```swift
// 速度で判定
速度 < 10 km/h → 青 (徒歩)
速度 >= 10 km/h → 赤 (乗り物)
```

**変更後:**
```swift
// 測位方式で判定
GNSS → 青 (GNSS衛星測位)
GROUND_FIX → オレンジ (基地局測位)
```

## 🔧 コードの変更例

### データ取得

**変更前 (公共交通DB + Firebase):**
```swift
FirestoreService.shared.startListening()
// → bus_locations コレクションからバス位置を取得
```

**変更後 (AWS REST API):**
```swift
DataService.shared.deviceId = "nrf-352656100123456"
DataService.shared.startListening()
// → AWS API からデバイス位置を取得
```

### 地図表示

**変更前:**
```swift
@Published var currentBusLocation: BusLocation?

// 地図に表示
if let location = currentBusLocation {
    MapMarker(coordinate: location.coordinate)
}
```

**変更後:**
```swift
@Published var currentDeviceLocation: DeviceLocation?

// 地図に表示
if let location = currentDeviceLocation {
    MapMarker(coordinate: location.coordinate)
        .tint(location.markerColor)  // 測位方式で色分け
}
```

### 履歴表示

**変更前:**
```swift
@Published var locationHistory: [BusLocation] = []
// Firestoreから取得
```

**変更後:**
```swift
@Published var locationHistory: [DeviceLocation] = []

// AWS APIから取得
Task {
    await DataService.shared.fetchHistory()
    // DataService.shared.locationHistory に格納
}
```

## ⚠️ 移行時の注意点

### 1. データの互換性

公共交通DBとnRF Cloudデバイスではデータ形式が異なります:

| 項目 | 公共交通DB | nRF Cloud |
|-----|-----------|-----------|
| 更新頻度 | リアルタイム | 設定可能（推奨: 60秒） |
| 速度情報 | あり | なし |
| 方位情報 | あり | なし |
| 測位精度 | なし | あり |

### 2. 既存データの移行

Firestoreに保存されていたデータ:
- セーフゾーン設定
- イベント履歴
- ユーザー設定

→ AWS DynamoDBに移行する必要があります

### 3. UI調整が必要な箇所

以下のUIコンポーネントで`BusLocation` → `DeviceLocation`への置き換えが必要:

```swift
// 確認が必要なファイル
- MapView.swift
- ContentView.swift
- LocationIconPreview.swift
```

## 🧪 テスト方法

### 1. ビルドテスト

```bash
# Firebaseインポートエラーがないこと
Product → Build (Cmd + B)

# 期待される結果
Build Succeeded
0 errors
```

### 2. データ取得テスト

```swift
// AWS API設定後
DataService.shared.deviceId = "nrf-352656100123456"
DataService.shared.startListening()

// 期待されるログ
🚀 AWS APIからのデータ取得開始
🌐 AWS API: デバイスデータ取得中...
✅ 位置情報取得成功: (35.681236, 139.767125)
```

### 3. 地図表示テスト

```swift
// currentDeviceLocationが更新されること
// マーカー色がsourceに応じて変わること
GNSS → 青
GROUND_FIX → オレンジ
```

## 📋 削除チェックリスト

### Firebase削除

- [ ] Firebase SDKを削除
- [ ] GoogleService-Info.plistを削除
- [ ] Firestoreインポートを削除
- [ ] FCM関連コードを削除
- [ ] FirestoreService.swiftを削除

### 公共交通DB削除

- [ ] BusLocation.swiftを削除（DeviceLocation.swiftに置き換え）
- [ ] 公共交通DB参照コードを削除
- [ ] バス情報UIを削除（不要な場合）

### 新規ファイル追加

- [ ] DataService.swiftを追加
- [ ] DeviceLocation.swiftを追加
- [ ] APIModels.swiftを追加
- [ ] AWSNetworkService.swiftを追加
- [ ] PushNotificationHandler.swiftを追加

### ビルド確認

- [ ] ビルドエラーなし
- [ ] Firebase参照エラーなし
- [ ] BusLocation参照エラーなし
- [ ] アプリが起動する

## 🎉 メリット

### 1. シンプルなアーキテクチャ

```
変更前:
iPhone → Firebase/Firestore → 公共交通オープンデータ
      → nRF Cloud直接

変更後:
iPhone → AWS REST API → nRF Cloud
```

### 2. 統一されたデータソース

- 単一のAPI（AWS REST API）
- 単一のデータモデル（DeviceLocation）
- 統一された認証（API Key）

### 3. コスト削減

- Firebaseの従量課金削除
- 公共交通DBの不要なデータ取得削除
- AWS単一課金

### 4. 保守性向上

- ベンダーロックイン回避
- シンプルなコード
- テストしやすい

## 📚 関連ドキュメント

- **`BUILD_CHECKLIST_NO_FIREBASE.md`** - ビルド手順
- **`AWS_API_INTEGRATION.md`** - AWS API統合ガイド
- **`README_AWS_INTEGRATION.md`** - 実装サマリー
- **`api_specification.md`** - API仕様書

---

**削除完了日**: 2026-02-05  
**新アーキテクチャ**: AWS REST API専用  
**追跡対象**: nRF Cloudデバイスのみ  
**最小対応OS**: iOS 15.0+
