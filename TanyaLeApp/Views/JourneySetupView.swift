//
//  JourneySetupView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 08/07/26.
//

import SwiftUI
import CoreLocation

/// First step after landing page: Name and describe the journey.
/// After this, the maker proceeds to set the start point.
struct JourneySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var journeyName: String = ""
    @State private var journeyDescription: String = ""
    /// The journey just created; non-nil presents the set-start-point sheet.
    /// Driving the sheet with `item:` (not `isPresented:` + optional) hands
    /// the journey straight to the sheet content, so it can never race to a
    /// nil "Loading..." state.
    @State private var newJourney: Journey?
    
    // Shared app-wide GPS source — already warm if any earlier screen used it.
    private var locationManager = LocationManager.shared
    
    var journeyService = JourneyService.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Journey Details")) {
                    TextField("Journey Name", text: $journeyName)
                    
                    ZStack(alignment: .topLeading) {
                        if journeyDescription.isEmpty {
                            Text("Description (optional)")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $journeyDescription)
                            .frame(minHeight: 100)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("After naming your journey, you'll set the physical starting point where participants will begin their AR experience.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // GPS status indicator
                        HStack {
                            Image(systemName: gpsStatusIcon)
                                .foregroundStyle(gpsStatusColor)
                            Text(gpsStatusText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Create Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") {
                        createJourneyAndProceed()
                    }
                    .disabled(journeyName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                // Request location permission early
                print("🌍 Requesting location permission early...")
                locationManager.requestPermission()
            }
            .sheet(item: $newJourney) { journey in
                SetStartPointView(journey: journey)
            }
        }
    }
    
    // MARK: - GPS status label

    private var permissionDenied: Bool {
        locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted
    }

    private var gpsStatusIcon: String {
        if locationManager.userLocation != nil { return "location.fill" }
        return permissionDenied ? "location.slash" : "location"
    }

    private var gpsStatusColor: Color {
        if locationManager.userLocation != nil { return .green }
        return permissionDenied ? .red : .orange
    }

    private var gpsStatusText: String {
        if locationManager.userLocation != nil { return "GPS Ready" }
        if permissionDenied {
            return "Location permission is off — enable it in Settings → TanyaLe → Location"
        }
        return "GPS Initializing..."
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
    JourneySetupView()
}
