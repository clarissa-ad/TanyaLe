//
//  ARMinimapView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 07/07/26.
//

import SwiftUI
import MapKit

/// A self-contained floating minimap overlay: a checkpoint map with a custom AR
/// blue dot, plus show/hide and recenter controls. It owns its own display
/// state (`mapState`, `mapPosition`); callers only feed it data.
///
/// Trailing-aligned so it sits flush against whatever edge the parent places it
/// on (e.g. top-right). Defaults to `.hidden` — only the "show map" button shows
/// until the user taps it, which opens the map straight into `.expanded`.
struct ARMinimapView: View {
    /// Checkpoints to plot as green dots.
    let checkpoints: [Checkpoint]
    /// The user's live AR position, drawn as the blue dot and used by "recenter".
    let userLocation: CLLocationCoordinate2D?
    /// Where to snap the map when it first appears (e.g. the survey origin).
    let origin: CLLocationCoordinate2D?
    
    var locationManager = LocationManager.shared
    var db = MockDatabaseService.shared
    @State var selectedCheckpoint: Checkpoint?
    
    enum MapState {
        case hidden, expanded
    }
    
    /// Fixed minimap zoom level (max zoom).
    private let minimapSpan = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
    
    
    @State private var mapState: MapState = .hidden
    @State private var mapPosition = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -6.200000, longitude: 106.816666),
        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
    ))
    
    
    
    var body: some View {
        VStack(alignment: .trailing) {
            if mapState != .hidden {
                Map(position: $mapPosition) {
                    ForEach(db.checkpoints) { checkpoint in
                        Annotation("", coordinate: checkpoint.coordinate) {
                            Button(action: {
                                selectedCheckpoint = checkpoint
                            }) {
                                VStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .resizable()
                                        .frame(width: 30, height: 30)
                                        .foregroundStyle(.green)
                                    Text(checkpoint.title)
                                        .font(.caption)
                                        .bold()
                                        .padding(4)
                                        .background(Color.white.opacity(0.8))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                .frame(width: 300, height: 400)
                .cornerRadius(15)
                .shadow(radius: 5)
                .onAppear {
                    // Snap to origin when map appears
                    if let origin {
                        mapPosition = .region(MKCoordinateRegion(center: origin, span: minimapSpan))
                    }
                }
            }
            
            // Floating Toggle Buttons
            HStack(spacing: 15) {
                if mapState != .hidden {
                    Button(action: {
                        if let userLoc = userLocation {
                            withAnimation {
                                mapPosition = .region(MKCoordinateRegion(center: userLoc, span: minimapSpan))
                            }
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.9))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.blue)
                            .clipShape(Circle())
                            .foregroundStyle(.blue)
                    }
                }
                
                Button(action: {
                    withAnimation(.spring()) {
                        mapState = (mapState == .hidden) ? .expanded : .hidden
                    }
                }) {
                    Image(systemName: mapState == .hidden ? "map.fill" : "eye.slash.fill")
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.9))
                        .font(.system(size: 20, weight: .semibold))
                        .clipShape(Circle())
                }
            }
        }
    }
}

extension ARMinimapView {
    @ViewBuilder
    private func checkpointCard(for cp:Checkpoint) -> some View {
        Text("Checkpoint Details")
        
        if cp.hasMCQ || cp.hasEmojiSlider {
            Text(cp.question)
        }
    }
}
