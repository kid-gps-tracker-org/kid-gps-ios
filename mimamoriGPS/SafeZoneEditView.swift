//
//  SafeZoneEditView.swift
//  mimamoriGPS
//
//  セーフゾーン編集画面（簡素化版）
//

import SwiftUI
import MapKit
import FirebaseFirestore

struct SafeZoneEditView: View {
    // MARK: - Properties
    @Environment(\.dismiss) private var dismiss
    
    let childId: String
    let safeZone: SafeZone?
    @ObservedObject var firestoreService: FirestoreService
    let initialLocation: (latitude: Double, longitude: Double)?
    
    @State private var name: String = ""
    @State private var radius: Double = 100
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.4437, longitude: 139.6380),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    
    // 設定パネルの高さ（縮小）
    private let settingsPanelHeight: CGFloat = 200
    
    // MARK: - Initializer

    init(
        firestoreService: FirestoreService,
        childId: String,
        safeZone: SafeZone?,
        initialLocation: (latitude: Double, longitude: Double)?
    ) {
        self.firestoreService = firestoreService
        self.childId = childId
        self.safeZone = safeZone
        self.initialLocation = initialLocation
        
        if let zone = safeZone {
            _region = State(initialValue: MKCoordinateRegion(
                center: zone.centerCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else if let location = initialLocation {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.4437, longitude: 139.6380),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    private var isEditing: Bool {
        safeZone != nil
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                // 地図
                mapView
                
                // 設定パネル
                VStack {
                    Spacer()
                    settingsPanel
                }
            }
            .navigationTitle(isEditing ? "セーフゾーン編集" : "セーフゾーン追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSafeZone()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("保存結果", isPresented: $showingSaveAlert) {
                Button("OK") {
                    if saveAlertMessage.contains("成功") {
                        dismiss()
                    }
                }
            } message: {
                Text(saveAlertMessage)
            }
            .onAppear {
                loadExistingZone()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var mapView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Map(coordinateRegion: $region)
                    .ignoresSafeArea()
                    .frame(height: geometry.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleMapTap(at: location, in: geometry)
                    }
                
                if let location = selectedLocation {
                    let screenPoint = convertToScreenPoint(
                        coordinate: location,
                        region: region,
                        size: geometry.size
                    )
                    
                    ZStack {
                        // セーフゾーン円（青色固定）
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(
                                width: metersToPixels(meters: radius, region: region, screenHeight: geometry.size.height) * 2,
                                height: metersToPixels(meters: radius, region: region, screenHeight: geometry.size.height) * 2
                            )
                        
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(
                                width: metersToPixels(meters: radius, region: region, screenHeight: geometry.size.height) * 2,
                                height: metersToPixels(meters: radius, region: region, screenHeight: geometry.size.height) * 2
                            )
                        
                        // 中心マーカー
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                    .position(screenPoint)
                }
                
                // タップで設定の案内
                if selectedLocation == nil {
                    VStack {
                        Text("地図をタップして場所を選択")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.7))
                            )
                            .padding(.top, 60)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var settingsPanel: some View {
        VStack(spacing: 0) {
            // ハンドル
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)
            
            VStack(spacing: 16) {
                // 名前入力
                VStack(alignment: .leading, spacing: 8) {
                    Text("名前")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("例: 自宅、学校", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 半径設定
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("半径")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(radius))m")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Slider(value: $radius, in: 50...500, step: 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: settingsPanelHeight)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 10)
        )
    }
    
    // MARK: - Methods
    
    private func loadExistingZone() {
        guard let zone = safeZone else { return }
        
        name = zone.name
        radius = zone.radius
        selectedLocation = zone.centerCoordinate
    }
    
    private func handleMapTap(at location: CGPoint, in geometry: GeometryProxy) {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        
        let normalizedX = (location.x - screenWidth / 2) / screenWidth
        let normalizedY = (location.y - screenHeight / 2) / screenHeight
        
        let lat = region.center.latitude - normalizedY * region.span.latitudeDelta
        let lon = region.center.longitude + normalizedX * region.span.longitudeDelta
        
        selectedLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    private func convertToScreenPoint(
        coordinate: CLLocationCoordinate2D,
        region: MKCoordinateRegion,
        size: CGSize
    ) -> CGPoint {
        let centerLat = region.center.latitude
        let centerLon = region.center.longitude
        
        let spanLat = region.span.latitudeDelta
        let spanLon = region.span.longitudeDelta
        
        let normalizedX = (coordinate.longitude - centerLon) / spanLon
        let normalizedY = (centerLat - coordinate.latitude) / spanLat
        
        let x = size.width * (0.5 + normalizedX)
        let y = size.height * (0.5 + normalizedY)
        
        return CGPoint(x: x, y: y)
    }
    
    private func metersToPixels(
        meters: Double,
        region: MKCoordinateRegion,
        screenHeight: CGFloat
    ) -> CGFloat {
        let metersPerDegree = 111000.0
        let degreesPerScreen = region.span.latitudeDelta
        let metersPerScreen = degreesPerScreen * metersPerDegree
        let pixelsPerMeter = Double(screenHeight) / metersPerScreen
        
        return CGFloat(meters * pixelsPerMeter)
    }
    
    private var isValid: Bool {
        !name.isEmpty && selectedLocation != nil
    }
    
    private func saveSafeZone() {
        guard let location = selectedLocation else { return }
        
        let newZone = SafeZone(
            id: safeZone?.id,
            name: name,
            center: GeoPoint(location),
            radius: radius,
            childId: childId,
            createdBy: "current-user",
            color: "#007AFF",  // 青色固定
            isActive: true
        )
        
        if isEditing {
            firestoreService.updateSafeZone(newZone) { [self] result in
                switch result {
                case .success:
                    print("✅ セーフゾーン更新成功")
                    dismiss()
                    
                case .failure(let error):
                    saveAlertMessage = "更新エラー: \(error.localizedDescription)"
                    showingSaveAlert = true
                }
            }
        } else {
            firestoreService.addSafeZone(newZone) { [self] result in
                switch result {
                case .success:
                    print("✅ セーフゾーン追加成功")
                    dismiss()
                    
                case .failure(let error):
                    saveAlertMessage = "追加エラー: \(error.localizedDescription)"
                    showingSaveAlert = true
                }
            }
        }
    }
}

// MARK: - Preview

struct SafeZoneEditView_Previews: PreviewProvider {
    static var previews: some View {
        SafeZoneEditView(
            firestoreService: FirestoreService(),
            childId: "test-child-001",
            safeZone: nil,
            initialLocation: nil
        )
    }
}
