# mimamoriGPS - 実装サマリー

**最終更新日**: 2026-02-16  
**ドキュメントバージョン**: v1.3  

---

## 📦 実装概要

AWS REST API を唯一のデータソースとするiPhoneアプリ。  
デバイスの位置情報・温度情報のリアルタイム表示、セーフゾーン管理、入退場履歴の確認ができる。

---

## 📱 画面構成（タブ）

| タブ | 画面 | 主な機能 |
|-----|------|---------|
| 今日 | `DateSelectionView` | 軌跡を表示する日付を選択 |
| 地図 | `MapView` | リアルタイム位置・温度・セーフゾーン・軌跡表示 |
| 履歴 | `ZoneEventListView` | セーフゾーン入退場イベント一覧 |
| 設定 | `SettingsView` | セーフゾーン管理・AWS API設定へのナビゲーションハブ |

---

## 🗂 ファイル一覧

### 新規作成ファイル

| ファイル名 | バージョン | 説明 |
|-----------|----------|------|
| `APIModels.swift` | v1.0 | API仕様書の全データ型 |
| `AWSNetworkService.swift` | v1.0 | AWS REST API通信（全10エンドポイント） |
| `DataService.swift` | v1.0 | データサービス補助クラス |
| `DeviceLocation.swift` | v1.0 | デバイス位置モデル |
| `SettingsView.swift` | **v1.3** | 設定ハブ画面（新規追加） |

### 主要修正ファイル

| ファイル名 | 最終更新 | 主な変更内容 |
|-----------|---------|------------|
| `FirestoreService.swift` | **v1.3** | `lastTemperature` 追加、インスタンス共有対応、楽観的更新 |
| `MapView.swift` | **v1.3** | `BusInfoCard` に温度表示追加、歯車ボタン削除 |
| `ContentView.swift` | **v1.3** | タブ4をセーフゾーン→設定に変更、`settingsResetID` によるリセット対応 |
| `SafeZoneListView.swift` | **v1.2** | `NavigationView` 削除、`@ObservedObject` 受け取りに変更 |
| `SafeZoneEditView.swift` | **v1.2** | 既存セーフゾーンをグレー円でオーバーレイ表示 |
| `NRFCloudSettingsView.swift` | **v1.3** | `NavigationView` 削除（`SettingsView` からの push 遷移に対応） |

---

## ✅ 実装済み機能

### 位置・温度情報
- [x] リアルタイム位置表示（60秒ポーリング）
- [x] GNSS / GROUND_FIX 測位方式の識別と表示
- [x] **温度情報の取得・表示**（`Device.lastTemperature` から）
- [x] 温度の色分け表示（青〜赤）
- [x] データが古い場合の警告表示

### 軌跡
- [x] 日付指定での軌跡表示
- [x] 時間ベースの透過度表示（新しいほど濃い）
- [x] 軌跡ポイントのタップで時刻詳細表示

### セーフゾーン
- [x] セーフゾーン一覧表示
- [x] 追加・編集・削除（楽観的更新で即時反映）
- [x] 地図上への円オーバーレイ表示
- [x] **セーフゾーン編集時に既存ゾーンをグレー表示**
- [x] 最大10件制限

### 設定
- [x] **設定ハブ画面（`SettingsView`）**
  - セーフゾーン設定へのナビゲーション
  - AWS API設定へのナビゲーション
  - AWS API未設定時の「要設定」バッジ表示
  - タブを離れるたびに設定トップにリセット
- [x] AWS API設定（Base URL / API Key / Device ID / 表示名）

### 履歴
- [x] セーフゾーン入退場イベント一覧
- [x] ZONE_ENTER / ZONE_EXIT の区別表示

---

## 🔄 データフロー

```
AWS API
 │
 ├─ GET /devices（60秒ごと）
 │    ├─ lastLocation → FirestoreService.currentBusLocation → MapView マーカー
 │    └─ lastTemperature → FirestoreService.lastTemperature → BusInfoCard 温度表示
 │
 ├─ GET /devices/{id}/history（日付変更時・位置変化時）
 │    └─ GNSS履歴 → FirestoreService.locationHistory → 軌跡表示
 │
 ├─ GET /devices/{id}/safezones（300秒ごと）
 │    └─ → FirestoreService.safeZones → 地図円オーバーレイ
 │
 └─ GET /devices/{id}/history?type=ZONE_ENTER|ZONE_EXIT（300秒ごと）
      └─ → FirestoreService.zoneEvents → 履歴タブ
```

---

## 🏗 アーキテクチャ

### FirestoreService の共有方法

```
ContentView（@StateObject → 唯一のインスタンス）
 ├── MapView（@ObservedObject）
 ├── ZoneEventListView（@ObservedObject）
 └── SettingsView（@ObservedObject）
      └── SafeZoneListView（@ObservedObject）
           └── SafeZoneEditView（@ObservedObject）
```

すべての画面が同一インスタンスを参照するため、セーフゾーン追加後に即座に地図へ反映される。

### セーフゾーン楽観的更新

```swift
func addSafeZone(_ zone: SafeZone, completion: ...) {
    safeZones.append(zone)          // ① 即座にローカル反映
    Task {
        try await API.putSafeZone() // ② バックグラウンドで送信
        await fetchSafeZonesFromAWS() // ③ サーバーと同期
        // 失敗時: safeZones.removeAll { $0.id == zone.id } でロールバック
    }
}
```

---

## ⚙️ 設定項目

| UserDefaults キー | 内容 | 設定箇所 |
|-----------------|------|---------|
| `aws_base_url` | API Gateway URL | 設定 → AWS API設定 |
| `aws_api_key` | API認証キー | 設定 → AWS API設定 |
| `nrf_device_id` | デバイスID | 設定 → AWS API設定 |
| `device_display_name` | 地図カード表示名 | 設定 → AWS API設定 |

---

## 📋 変更履歴

| バージョン | 日付 | 主な変更内容 |
|-----------|------|------------|
| v1.0 | 2026-02-05 | 初版。AWS REST API統合、Firebase削除 |
| v1.1 | 2026-02-10 | セーフゾーンCRUD実装、地図オーバーレイ |
| v1.2 | 2026-02-14 | FirestoreService インスタンス共有統一、楽観的更新、セーフゾーン編集画面に既存ゾーン表示 |
| **v1.3** | **2026-02-16** | **設定タブ追加（SettingsView）、温度情報表示、歯車ボタン整理、設定ナビゲーションリセット** |

---

## 🔧 ビルド手順

```
1. Cmd + Shift + K（Clean Build Folder）
2. Cmd + R（ビルド & 実行）
3. 設定タブ → AWS API設定 で接続情報を入力
```

---

## 📄 関連ドキュメント

- **統合ガイド（詳細）**: `AWS_API_INTEGRATION.md`
- **ビルドチェックリスト**: `BUILD_CHECKLIST.md`
