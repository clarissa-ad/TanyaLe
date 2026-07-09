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
                    ForEach(checkpoints) { cp in
                        Annotation("", coordinate: cp.coordinate) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 15, height: 15)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                    }

                    // Custom AR blue dot for indoor tracking — a real map
                    // annotation, so it stays put when the map is panned.
                    if let userLoc = userLocation {
                        Annotation("", coordinate: userLoc) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 15, height: 15)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 2)
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
