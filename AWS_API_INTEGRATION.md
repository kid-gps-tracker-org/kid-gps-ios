# AWS REST API 統合ガイド

## 概要

このiPhoneアプリは、AWS REST API仕様書 v1.0 に準拠した実装を含んでいます。
3つのデータソースから位置情報を取得できます:

1. **公共交通DB (Firebase)** - 既存のバス位置データ
2. **nRF Cloud (直接接続)** - nRF Cloud APIから直接取得
3. **AWS REST API** - AWS Lambda経由でnRF Cloudデバイスの情報を取得（推奨）

## 新規追加ファイル

### 1. `Models/APIModels.swift`
API仕様書のすべてのデータ型を定義:
- Location, Temperature, Coordinate
- Device, SafeZone, HistoryEntry
- FirmwareInfo, FotaJob
- ApiError
- 各エンドポイントのリクエスト/レスポンス型

**重要な実装ポイント:**
- ISO8601DateFormatter with fractional seconds (`.withFractionalSeconds`)
- すべてのタイムスタンプは `String` 型で、ISO 8601形式
- `null` 値は `Optional` 型で表現

### 2. `Services/AWSNetworkService.swift`
AWS REST APIとの通信を担当:
- 全10個のエンドポイントを実装
- API Key認証 (`x-api-key` ヘッダー)
- エラーハンドリング（ApiError型のデコード）
- 設定管理（UserDefaults経由）

**実装済みエンドポイント:**
- `GET /devices` - デバイス一覧
- `GET /devices/{deviceId}/location` - 最新位置
- `GET /devices/{deviceId}/temperature` - 最新温度
- `GET /devices/{deviceId}/history` - 履歴取得
- `GET /devices/{deviceId}/safezones` - セーフゾーン一覧
- `PUT /devices/{deviceId}/safezones` - セーフゾーン作成・更新
- `DELETE /devices/{deviceId}/safezones/{zoneId}` - セーフゾーン削除
- `GET /devices/{deviceId}/firmware` - ファームウェア情報
- `POST /devices/{deviceId}/firmware/update` - ファームウェア更新
- `GET /devices/{deviceId}/firmware/status` - FOTA ジョブステータス

### 3. `Services/PushNotificationHandler.swift`
APNsプッシュ通知のペイロードを処理:
- `ZONE_ENTER` - セーフゾーン帰還通知
- `ZONE_EXIT` - セーフゾーン離脱通知
- NotificationCenterを使用してアプリ内に通知を伝播

### 4. 既存ファイルの修正

#### `FirestoreService.swift`
- データソース選択機能を追加（enum DataSource）
- AWS APIからの位置情報取得 (`fetchLocationFromAWS`)
- AWS APIからのセーフゾーン取得 (`fetchSafeZonesFromAWS`)
- セーフゾーンCRUD操作でAWS API使用

#### `NRFCloudSettingsView.swift`
- データソース選択UI
- AWS API設定フィールド（Base URL, API Key）
- 設定手順の表示
- 設定状態の表示

#### `mimamoriGPSApp.swift`
- `PushNotificationHandler` を使用した通知処理

## 設定方法

### AWS REST APIを使用する場合

1. **設定画面を開く**
   - アプリ内の設定アイコンをタップ

2. **データソースを選択**
   - 「AWS REST API」を選択

3. **AWS API設定を入力**
   - **Base URL**: `https://{api-id}.execute-api.ap-northeast-1.amazonaws.com/dev`
   - **API Key**: API Gatewayで発行されたAPIキー
   - **Device ID**: `nrf-352656100123456` (nRF CloudのデバイスID)

4. **設定を保存**
   - 「設定を保存」ボタンをタップ

## API仕様書との対応

### タイムスタンプ形式（1.2節）
```swift
// ISO 8601 / UTC / ミリ秒精度
let formatter = ISO8601DateFormatter.withFractionalSeconds
// 例: "2026-02-05T12:34:56.789Z"
```

### 座標系（1.4節）
```swift
struct Coordinate {
    let lat: Double  // -90.0 〜 90.0
    let lon: Double  // -180.0 〜 180.0
}
```

### null ハンドリング（1.3節）
- レスポンスのnullフィールドは `Optional` 型
- 例: `let lastLocation: Location?`

### エラーハンドリング（3.9節、5節）
```swift
struct ApiError {
    let error: ErrorDetail
    struct ErrorDetail {
        let code: String  // SCREAMING_SNAKE_CASE
        let message: String
    }
}
```

## プッシュ通知

### APNsペイロード形式（6.1、6.2節）

**セーフゾーン離脱 (ZONE_EXIT):**
```json
{
  "aps": {
    "alert": {
      "title": "セーフゾーンアラート",
      "body": "デバイスがセーフゾーン「自宅」から離れました"
    },
    "sound": "default",
    "badge": 1
  },
  "data": {
    "type": "ZONE_EXIT",
    "deviceId": "nrf-352656100123456",
    "zoneId": "550e8400-e29b-41d4-a716-446655440000",
    "zoneName": "自宅",
    "location": { ... },
    "detectedAt": "2026-02-05T12:30:05.000Z"
  }
}
```

**処理フロー:**
1. APNsからペイロード受信
2. `PushNotificationHandler.handleNotification()` 呼び出し
3. `data` フィールドをパース
4. `PushNotificationData` 型に変換
5. `NotificationCenter` で通知

## テスト方法

### 1. 設定のテスト
```swift
// AWSNetworkService.isConfigured() が true を返すことを確認
let configured = AWSNetworkService.shared.isConfigured()
```

### 2. API呼び出しテスト
```swift
Task {
    do {
        let devices = try await AWSNetworkService.shared.getDevices()
        print("✅ デバイス取得成功: \(devices.devices.count)件")
    } catch {
        print("❌ エラー: \(error)")
    }
}
```

### 3. セーフゾーンテスト
```swift
Task {
    do {
        let zones = try await AWSNetworkService.shared.getSafeZones(deviceId: "nrf-352656100123456")
        print("✅ セーフゾーン取得成功: \(zones.safezones.count)件")
    } catch {
        print("❌ エラー: \(error)")
    }
}
```

## トラブルシューティング

### 「AWS APIの設定が完了していません」エラー
- 設定画面でBase URLとAPI Keyが入力されているか確認
- Base URLに `{api-id}` が残っていないか確認

### 「APIエラー [MISSING_API_KEY]」
- API Keyが正しく設定されているか確認
- AWS API Gatewayでキーが有効になっているか確認

### 「APIエラー [DEVICE_NOT_FOUND]」
- Device IDが正しいか確認（形式: `nrf-{IMEI 15桁}`）
- nRF Cloudにデバイスが登録されているか確認

### プッシュ通知が届かない
- 通知権限が許可されているか確認
- FCMトークンがAWSに登録されているか確認
- APNs証明書がAWSに設定されているか確認

## データモデルの変換

### API → アプリ内モデル

**APISafeZone → SafeZone:**
```swift
func convertAPISafeZoneToSafeZone(_ apiZone: APISafeZone, deviceId: String) -> SafeZone {
    SafeZone(
        id: apiZone.zoneId,
        name: apiZone.name,
        center: GeoPoint(latitude: apiZone.center.lat, longitude: apiZone.center.lon),
        radius: apiZone.radius,
        childId: deviceId,
        createdBy: "aws",
        color: "#0000FF",
        icon: "home",
        isActive: apiZone.enabled
    )
}
```

**Location → BusLocation:**
```swift
func convertLocationToBusLocation(_ location: Location, deviceId: String) -> BusLocation {
    BusLocation(
        id: deviceId,
        latitude: location.lat,
        longitude: location.lon,
        timestamp: Timestamp(date: location.date ?? Date()),
        speed: nil,
        azimuth: nil,
        fromBusstopPole: nil,
        toBusstopPole: nil,
        busOperator: "nRF Device",
        busRoute: deviceId
    )
}
```

## 今後の拡張

### 実装予定の機能
- [ ] 履歴表示UI（HistoryEntry表示）
- [ ] 温度グラフ表示
- [ ] ファームウェア更新UI
- [ ] プッシュ通知の履歴表示
- [ ] オフライン対応（キャッシュ）

### AWS側の実装が必要な機能
- Lambda関数の実装（各エンドポイント）
- DynamoDB テーブルの作成
- API Gatewayの設定
- SNS → APNs連携の設定
- nRF Cloud Webhook → Lambda連携

## 参考資料

- **API仕様書**: `api_specification.md`
- **システム仕様書**: `specification.md` (参照されている場合)
- **インターフェース設計書**: `interface_design.md` (参照されている場合)

## ライセンス

このコードは API仕様書 v1.0 に厳密に準拠して実装されています。
