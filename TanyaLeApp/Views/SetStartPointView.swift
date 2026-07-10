//
//  SetStartPointView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 08/07/26.
//

import SwiftUI
import MapKit
import CoreLocation

/// Second step of the creation flow (pushed, step 2 of 4): a live map shows
/// the maker where they're standing so they can pick the journey's physical
/// starting point, then continue to AR checkpoint placement.
struct SetStartPointView: View {
    @Environment(\.dismiss) private var dismiss
    @State var journey: Journey
    var locationManager: LocationManager = .shared
    /// Forwarded to the AR placement flow; ends the whole creation flow.
    var onFlowFinished: () -> Void = {}

    @State private var showARPlacement = false
    @State private var hasSetStartPoint = false
    /// Follows the user's position; falls back to Jakarta until the first fix.
    @State private var mapPosition: MapCameraPosition = .userLocation(
        fallback: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -6.200000, longitude: 106.816666),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    )

    var journeyService = JourneyService.shared

    var body: some View {
        ZStack {
            Color.brandDeepPurple
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                mapCard

                actionCard
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Best accuracy while pinpointing the start location.
            locationManager.improveAccuracy()
        }
        .fullScreenCover(isPresented: $showARPlacement) {
            JourneyARPlacementView(journey: journey, onFlowFinished: onFlowFinished)
        }
    }

    // MARK: - Header (back button + step dots)

    private var header: some View {
        ZStack {
            // Step 2 of 4 in the creation flow.
            HStack(spacing: 12) {
                ForEach(0..<4) { step in
                    Circle()
                        .fill(step == 1 ? Color.brandPurple : Color.white.opacity(0.85))
                        .frame(width: 10, height: 10)
                }
            }

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.25), in: Circle())
                }
                .accessibilityLabel("Back")

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Map

    private var mapCard: some View {
        Map(position: $mapPosition) {
            // The maker's live position — the whole point of this page.
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            if locationManager.userLocation == nil {
                // No fix yet: keep the map visible but explain the wait.
                VStack(spacing: 8) {
                    ProgressView()
                    Text(waitingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Bottom card

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Starting Point")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Go to the physical location where participants will begin this journey, then set the point below.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: setStartPoint) {
                HStack {
                    Image(systemName: hasSetStartPoint ? "checkmark.circle.fill" : "mappin.circle.fill")
                    Text(hasSetStartPoint ? "Start Point Set!" : "Set Start Point Here")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    hasSetStartPoint
                        ? Color.green
                        : Color.brandPurple.opacity(locationManager.userLocation == nil ? 0.4 : 1),
                    in: Capsule()
                )
            }
            .disabled(locationManager.userLocation == nil)

            if hasSetStartPoint {
                Button {
                    showARPlacement = true
                } label: {
                    HStack {
                        Text("Continue to Place Checkpoints")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white, in: Capsule())
                    .foregroundStyle(LinearGradient.brandPurpleButton())
                    .overlay(
                        Capsule()
                            .stroke(LinearGradient.brandPurpleButton(), lineWidth: 2)
                    )
                }
            }
        }
        .padding(24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            Color.white,
            in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32)
        )
        .ignoresSafeArea(edges: .bottom)
        .animation(.spring(duration: 0.35), value: hasSetStartPoint)
    }

    private var waitingText: String {
        if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            return "Location permission is off — enable it in Settings → TanyaLe → Location"
        }
        return "Waiting for GPS…"
    }

    // MARK: - Actions

    private func setStartPoint() {
        guard let location = locationManager.userLocation else { return }

        // Update journey with GPS coordinates
        journey.startLatitude = location.coordinate.latitude
        journey.startLongitude = location.coordinate.longitude

        // AR origin will be set in the AR view when placing checkpoints
        journeyService.updateJourney(journey)

        withAnimation {
            hasSetStartPoint = true
        }
    }
}

#Preview {
    NavigationStack {
        SetStartPointView(journey: Journey(name: "Test Journey"))
    }
}
