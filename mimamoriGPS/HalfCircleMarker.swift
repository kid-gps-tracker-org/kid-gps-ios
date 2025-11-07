//
//  HalfCircleMarker.swift
//  mimamoriGPS
//
//  半分色付き・半分グレーの軌跡マーカー（速度対応版）
//

import SwiftUI

/// 半分色付き円マーカー（進行方向表示用・速度で色分け）
struct HalfCircleMarker: View {
    let azimuth: Double   // 進行方向の角度（度）
    let opacity: Double   // 透過度（0.3〜0.7）
    let color: Color      // マーカーの色（速度に応じて変わる）
    
    var body: some View {
        ZStack {
            // 色付き半分（進行方向側）- 速度で色が変わる
            Circle()
                .trim(from: 0.5, to: 1.0)
                .fill(color.opacity(opacity))
                .frame(width: 12, height: 12)
                        
            // グレー半分（後ろ側）
            Circle()
                .trim(from: 0.0, to: 0.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 12, height: 12)
            
            // 白い境界線
            Circle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: 12, height: 12)
        }
        .rotationEffect(.degrees(azimuth))  // 進行方向に回転
        .shadow(radius: 1)
        .animation(nil)  // すべてのアニメーションを無効化
        .transaction { transaction in
            transaction.disablesAnimations = true
            transaction.animation = nil
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
        
        VStack(spacing: 30) {
            // 徒歩（青）
            HStack(spacing: 20) {
                HalfCircleMarker(azimuth: 0, opacity: 0.7, color: .blue)
                Text("徒歩 (青色)")
                    .font(.caption)
            }
            
            // 車両（赤）
            HStack(spacing: 20) {
                HalfCircleMarker(azimuth: 0, opacity: 0.7, color: .red)
                Text("車両 (赤色)")
                    .font(.caption)
            }
            
            // 方向バリエーション
            Text("進行方向の例")
                .font(.headline)
                .padding(.top)
            
            HStack(spacing: 15) {
                VStack {
                    HalfCircleMarker(azimuth: 0, opacity: 0.7, color: .blue)
                    Text("→ 東").font(.caption)
                }
                VStack {
                    HalfCircleMarker(azimuth: 90, opacity: 0.7, color: .red)
                    Text("↓ 南").font(.caption)
                }
                VStack {
                    HalfCircleMarker(azimuth: 180, opacity: 0.7, color: .blue)
                    Text("← 西").font(.caption)
                }
                VStack {
                    HalfCircleMarker(azimuth: 270, opacity: 0.7, color: .red)
                    Text("↑ 北").font(.caption)
                }
            }
            
            // 透過度バリエーション
            Text("透過度の例（時間経過）")
                .font(.headline)
                .padding(.top)
            
            HStack(spacing: 15) {
                VStack {
                    HalfCircleMarker(azimuth: 0, opacity: 0.7, color: .blue)
                    Text("最近\n(0.7)").font(.caption2)
                        .multilineTextAlignment(.center)
                }
                VStack {
                    HalfCircleMarker(azimuth: 0, opacity: 0.5, color: .blue)
                    Text("4時間前\n(0.5)").font(.caption2)
                        .multilineTextAlignment(.center)
                }
                VStack {
                    HalfCircleMarker(azimuth: 0, opacity: 0.25, color: .blue)
                    Text("8時間前\n(0.25)").font(.caption2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
    }
}
