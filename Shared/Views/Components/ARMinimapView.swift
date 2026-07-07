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
/// state (`mapState`, `mapRegion`); callers only feed it data.
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

    @State private var mapState: MapState = .hidden
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -6.200000, longitude: 106.816666),
        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001) // Max zoom
    )

    var body: some View {
        VStack(alignment: .trailing) {
            if mapState != .hidden {
                Map(coordinateRegion: $mapRegion, annotationItems: checkpoints) { cp in
                    MapAnnotation(coordinate: cp.coordinate) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 15, height: 15)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }
                .frame(width: 300, height: 400)
                .cornerRadius(15)
                .shadow(radius: 5)
                .overlay(
                    // Custom AR Blue Dot for Indoor Tracking
                    Group {
                        if let userLoc = userLocation {
                            GeometryReader { proxy in
                                let mapCenter = mapRegion.center
                                let span = mapRegion.span

                                // Convert coordinates to screen points based on region
                                // This is a rough estimation for the minimap preview
                                let xOffset = (userLoc.longitude - mapCenter.longitude) / span.longitudeDelta * Double(proxy.size.width)
                                let yOffset = (mapCenter.latitude - userLoc.latitude) / span.latitudeDelta * Double(proxy.size.height)

                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 15, height: 15)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .shadow(radius: 2)
                                    .position(x: proxy.size.width / 2 + CGFloat(xOffset),
                                              y: proxy.size.height / 2 + CGFloat(yOffset))
                                    .animation(.linear(duration: 0.2), value: userLoc.latitude)
                            }
                        }
                    }
                )
                .onAppear {
                    // Snap to origin when map appears
                    if let origin {
                        mapRegion.center = origin
                    }
                }
            }

            // Floating Toggle Buttons
            HStack(spacing: 15) {
                if mapState != .hidden {
                    Button(action: {
                        if let userLoc = userLocation {
                            withAnimation {
                                mapRegion.center = userLoc
                            }
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .padding(10)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(radius: 3)
                            .foregroundColor(.blue)
                    }
                }

                Button(action: {
                    withAnimation(.spring()) {
                        mapState = (mapState == .hidden) ? .expanded : .hidden
                    }
                }) {
                    Image(systemName: mapState == .hidden ? "map.fill" : "eye.slash.fill")
                        .padding(10)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                        .shadow(radius: 3)
                }
            }
            .padding(.top, 5)
        }
        .padding()
    }
}
