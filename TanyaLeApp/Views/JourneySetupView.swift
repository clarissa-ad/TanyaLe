//
//  JourneySetupView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 08/07/26.
//

import SwiftUI
import CoreLocation

/// First step of the creation flow (pushed from the landing page, per the
/// Figma design): deep purple screen with the Lele mascot, and a white card
/// holding the survey title + optional description and a Create button.
struct JourneySetupView: View {
    @Environment(\.dismiss) private var dismiss
    /// Ends the whole creation flow: the landing page pops this page (and
    /// everything pushed above it) with a single state change.
    var onFlowFinished: () -> Void = {}

    @State private var journeyName: String = ""
    @State private var journeyDescription: String = ""
    /// The journey just created; non-nil pushes the set-start-point page.
    /// Driving the push with `item:` hands the journey straight to the
    /// destination, so it can never race to a nil "Loading..." state.
    @State private var newJourney: Journey?

    // Shared app-wide GPS source — already warm if any earlier screen used it.
    // Not `private`: a private stored property would make the memberwise
    // initializer private too, hiding init(onFlowFinished:) from callers.
    var locationManager = LocationManager.shared

    var journeyService = JourneyService.shared

    private var canCreate: Bool {
        !journeyName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.brandDeepPurple
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer(minLength: 12)

                // Mascot peeks out from behind the details card.
                Image("welcome")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(1.25)
                    .offset(x: 50, y: 50)

                detailsCard
            }
        }
        .dismissKeyboardOnTap()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Request location permission early so GPS is warm for the
            // set-start-point step.
            locationManager.requestPermission()
        }
        .navigationDestination(item: $newJourney) { journey in
            // The landing page pops the whole subtree in one state change.
            SetStartPointView(journey: journey, onFlowFinished: onFlowFinished)
        }
    }

    // MARK: - Header (back button + step dots)

    private var header: some View {
        ZStack {
            // Step 1 of 4 in the creation flow.
            HStack(spacing: 12) {
                ForEach(0..<4) { step in
                    Circle()
                        .fill(step == 0 ? Color.brandPurple : Color.white.opacity(0.85))
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

    // MARK: - Details card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Survey Details")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            // Title + description share one soft-gray group, like the design.
            VStack(spacing: 0) {
                TextField("Title", text: $journeyName)
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                Divider()
                    .padding(.horizontal, 20)

                ZStack(alignment: .topLeading) {
                    if journeyDescription.isEmpty {
                        Text("Description (optional)")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                    }
                    TextEditor(text: $journeyDescription)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .frame(minHeight: 160)
                }
            }
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 24))

            Button(action: createJourneyAndProceed) {
                Text("Create Survey")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Color.brandPurple.opacity(canCreate ? 1 : 0.4),
                        in: Capsule()
                    )
            }
            .disabled(!canCreate)

            // Subtle GPS heads-up for the next step (set start point).
            if gpsStatusText != nil {
                HStack(spacing: 6) {
                    Image(systemName: permissionDenied ? "location.slash" : "location")
                    Text(gpsStatusText ?? "")
                }
                .font(.caption2)
                .foregroundStyle(permissionDenied ? .red : .secondary)
                .frame(maxWidth: .infinity)
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
    }

    // MARK: - GPS status

    private var permissionDenied: Bool {
        locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted
    }

    /// `nil` once GPS is ready — the happy path shows no status noise.
    private var gpsStatusText: String? {
        if locationManager.userLocation != nil { return nil }
        if permissionDenied {
            return "Location permission is off — enable it in Settings → TanyaLe → Location"
        }
        return "Getting GPS ready for the next step…"
    }

    private func createJourneyAndProceed() {
        let journey = Journey(
            name: journeyName.trimmingCharacters(in: .whitespaces),
            description: journeyDescription.trimmingCharacters(in: .whitespaces)
        )

        journeyService.createJourney(journey)
        // Setting the item presents the sheet.
        newJourney = journey
    }
}

#Preview {
    NavigationStack {
        JourneySetupView()
    }
}
