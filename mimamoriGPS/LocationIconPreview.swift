//
//  LocationIconPreview.swift
//  mimamoriGPS
//
//  「探す」アプリ風アイコンのプレビュー
//

import SwiftUI

/// アイコン候補のプレビュー
struct LocationIconPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                Text("「探す」アプリ風アイコン候補")
                    .font(.title2)
                    .bold()
                    .padding(.top)
                
                // 現在のデザイン
                Group {
                    Text("現在のデザイン")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    IconSample(
                        icon: nil,
                        name: "シンプルな円",
                        description: "現在使用中",
                        color: .blue
                    )
                }
                
                Divider()
                
                // 人型アイコン
                Group {
                    Text("人型アイコン")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    IconSample(
                        icon: "person.fill",
                        name: "person.fill",
                        description: "シンプルな人型（推奨）",
                        color: .blue
                    )
                    
                    IconSample(
                        icon: "person.circle.fill",
                        name: "person.circle.fill",
                        description: "人型＋円背景",
                        color: .blue
                    )
                    
                    IconSample(
                        icon: "person.crop.circle.fill",
                        name: "person.crop.circle.fill",
                        description: "人型（円形トリミング）",
                        color: .blue
                    )
                }
                
                Divider()
                
                // 動きのある人型
                Group {
                    Text("動きのある人型")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    IconSample(
                        icon: "figure.walk",
                        name: "figure.walk",
                        description: "歩く人",
                        color: .blue
                    )
                    
                    IconSample(
                        icon: "figure.wave",
                        name: "figure.wave",
                        description: "手を振る人",
                        color: .blue
                    )
                    
                    IconSample(
                        icon: "figure.stand",
                        name: "figure.stand",
                        description: "立っている人",
                        color: .blue
                    )
                }
                
                Divider()
                
                // 位置マーカー型
                Group {
                    Text("位置マーカー型")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    IconSample(
                        icon: "mappin.circle.fill",
                        name: "mappin.circle.fill",
                        description: "ピン＋円",
                        color: .blue
                    )
                    
                    IconSample(
                        icon: "location.fill",
                        name: "location.fill",
                        description: "位置マーカー",
                        color: .blue
                    )
                    
                    IconSample(
                        icon: "location.circle.fill",
                        name: "location.circle.fill",
                        description: "位置マーカー＋円",
                        color: .blue
                    )
                }
                
                Divider()
                
                // 色のバリエーション
                Group {
                    Text("色のバリエーション（person.fill）")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    HStack(spacing: 20) {
                        VStack {
                            IconSample(
                                icon: "person.fill",
                                name: "",
                                description: "徒歩（青）",
                                color: .blue
                            )
                        }
                        
                        VStack {
                            IconSample(
                                icon: "person.fill",
                                name: "",
                                description: "車両（赤）",
                                color: .red
                            )
                        }
                        
                        VStack {
                            IconSample(
                                icon: "person.fill",
                                name: "",
                                description: "緑",
                                color: .green
                            )
                        }
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
    }
}

/// アイコンサンプル表示用
struct IconSample: View {
    let icon: String?
    let name: String
    let description: String
    let color: Color
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            // アイコン表示エリア
            ZStack {
                // 地図背景（イメージ）
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 150)
                
                // サンプル軌跡（小さい円）
                HStack(spacing: 8) {
                    ForEach(0..<5) { _ in
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 12, height: 12)
                    }
                }
                .offset(y: 20)
                
                // メインアイコン
                if let iconName = icon {
                    // SF Symbolsアイコン
                    ZStack {
                        Circle()
                            .fill(color)
                            .frame(width: 30, height: 30)
                            .opacity(isAnimating ? 0.3 : 1.0)
                        
                        Image(systemName: iconName)
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                            .opacity(isAnimating ? 0.3 : 1.0)
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .opacity(isAnimating ? 0.3 : 1.0)
                    )
                    .shadow(radius: 3)
                } else {
                    // シンプルな円
                    Circle()
                        .fill(color)
                        .frame(width: 30, height: 30)
                        .opacity(isAnimating ? 0.3 : 1.0)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .opacity(isAnimating ? 0.3 : 1.0)
                        )
                        .shadow(radius: 3)
                }
            }
            .onAppear {
                // 点滅アニメーション
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
            }
            
            // アイコン情報
            VStack(spacing: 4) {
                if !name.isEmpty {
                    Text(name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontDesign(.monospaced)
                }
                
                Text(description)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    LocationIconPreview()
}
