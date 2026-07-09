//
//  SetStartPointView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 08/07/26.
//

import SwiftUI
import CoreLocation

/// Second step: Set the physical starting point for the journey.
/// Shows instructions and captures GPS + AR origin when maker taps "Set Here".
struct SetStartPointView: View {
    @Environment(\.dismiss) private var dismiss
    @State var journey: Journey
    var locationManager: LocationManager = .shared
    @State private var showARPlacement = false
    @State private var hasSetStartPoint = false
    
    var journeyService = JourneyService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.brandPurple.opacity(0.05), Color.brandPurpleDark.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Icon
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.brandPurple, .brandPurpleDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.bottom, 20)
                    
                    // Instructions
                    VStack(spacing: 16) {
                        Text("Set Starting Point")
                            .font(.title.bold())
                        
                        Text("Go to the physical location where participants will begin this journey, then tap the button below.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        if let location = locationManager.userLocation {
                            VStack(spacing: 8) {
                                Label("GPS Ready", systemImage: "location.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                                
                                Text("Accuracy: ±\(Int(location.horizontalAccuracy))m")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        } else {
                            VStack(spacing: 8) {
                                Label("Waiting for GPS...", systemImage: "location.slash")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                
                                Text("Make sure location services are enabled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    Spacer()
                    
                    // Action Button
                    VStack(spacing: 16) {
                        Button {
                            setStartPoint()
                        } label: {
                            HStack {
                                Image(systemName: hasSetStartPoint ? "checkmark.circle.fill" : "mappin.circle.fill")
                                    .font(.title2)
                                Text(hasSetStartPoint ? "Start Point Set!" : "Set Start Point Here")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: hasSetStartPoint ? [.green, .green] : [.brandPurple, .brandPurpleDark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(15)
                        }
                        .disabled(locationManager.userLocation == nil)
                        
                        if hasSetStartPoint {
                            Button {
                                proceedToARPlacement()
                            } label: {
                                HStack {
                                    Text("Continue to Place Checkpoints")
                                        .font(.headline)
                                    Image(systemName: "arrow.right")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.brandPurple, .brandPurpleDark],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.brandPurple, .brandPurpleDark],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(journey.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                print("✅ SetStartPointView appeared with journey: \(journey.name)")
                // Upgrade to best accuracy now that user is ready to set point
                locationManager.improveAccuracy()
            }
            .fullScreenCover(isPresented: $showARPlacement) {
                JourneyARPlacementView(journey: journey)
            }
        }
    }
    
    private func setStartPoint() {
        guard let location = locationManager.userLocation else { return }
        
        // Update journey with GPS coordinates
        journey.startLatitude = location.coordinate.latitude
        journey.startLongitude = location.coordinate.longitude
        
        // AR origin will be set in the AR view when placing checkpoints
        // For now, just mark that we have a start point
        journeyService.updateJourney(journey)
        
        withAnimation {
            hasSetStartPoint = true
        }
    }
    
    private func proceedToARPlacement() {
        showARPlacement = true
    }
}

#Preview {
    SetStartPointView(journey: Journey(name: "Test Journey"))
}
