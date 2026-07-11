//
//  JourneyDetailView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 08/07/26.
//

import SwiftUI
import MapKit

/// Detailed view of a journey showing all info and management options.
/// This is the maker's dashboard for a specific journey.
struct JourneyDetailView: View {
    @State var journey: Journey
    @State private var showQRCode = false
    @State private var showEditCheckpoints = false
    @State private var showARPlacement = false
    
    var journeyService = JourneyService.shared
    var checkpointService = MockDatabaseService.shared
    
    var body: some View {
        List {
            // Journey Info Section — one compact row instead of a row per
            // field, so the section hugs its content (separate rows each
            // reserve the standard row height, leaving airy gaps for short
            // values like Status).
            Section(header: Text("Journey Info")) {
                LabeledContent("Name", value: journey.name)

                LabeledContent("Created", value: journey.createdDate.formatted(date: .long, time: .omitted))

                LabeledContent {
                        HStack(spacing: 6) {
                            if journey.isPublished {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Published")
                            } else {
                                Image(systemName: "pencil.circle")
                                Text("Draft")
                            }
                        }
                        // You can apply the color to the whole HStack at once!
                        .foregroundStyle(journey.isPublished ? .green : .orange)
                } label: {
                    Text("Status")
                }
                .padding(.vertical, 2)
                
                if !journey.description.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(journey.description)
                    }
                }
            }
            
            // Start Point Section
            Section(header: Text("Start Point")) {
                if journey.hasStartPoint {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Location Set", systemImage: "mappin.circle.fill")
                            .foregroundStyle(.green)
                        
                        Text("Lat: \(journey.startLatitude, specifier: "%.6f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Lng: \(journey.startLongitude, specifier: "%.6f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Label("Not set yet", systemImage: "mappin.slash")
                        .foregroundStyle(.orange)
                }
            }
            
            // Checkpoints Section
            Section(header: Text("Checkpoints")) {
                LabeledContent("Total", value: "\(journey.checkpointIDs.count)")
                
                Button {
                    showEditCheckpoints = true
                } label: {
                    Label("Manage Checkpoints", systemImage: "mappin.and.ellipse")
                }
            }
            
            // Actions Section
            Section(header: Text("Actions")) {
                if !journey.isPublished {
                    // Drafts can be resumed: jump back into AR placement to
                    // keep adding checkpoints where they left off.
                    Button {
                        showARPlacement = true
                    } label: {
                        Label("Continue Placing in AR", systemImage: "arkit")
                    }

                    Button {
                        publishJourney()
                    } label: {
                        Label("Publish Journey", systemImage: "arrow.up.circle.fill")
                    }
                    .disabled(!journey.hasStartPoint || journey.checkpointIDs.isEmpty)
                }
                
                if journey.isPublished, let _ = journey.qrCodeData {
                    Button {
                        showQRCode = true
                    } label: {
                        Label("View QR Code", systemImage: "qrcode")
                    }
                }
                
                Button(role: .destructive) {
                    deleteJourney()
                } label: {
                    Label("Delete Journey", systemImage: "trash")
                }
            }
        }
        .listSectionSpacing(.compact)
        .navigationTitle(journey.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showQRCode) {
            QRCodeView(journey: journey)
        }
        .sheet(isPresented: $showEditCheckpoints) {
            // Scoped to this journey; the navigation stack makes the
            // edit-checkpoint and responses links work inside the sheet.
            NavigationView {
                CheckpointListView(journey: journey)
            }
        }
        .fullScreenCover(isPresented: $showARPlacement, onDismiss: {
            // Pick up checkpoints added during the AR session — our local
            // journey is a value-type snapshot and doesn't update itself.
            if let updated = journeyService.getJourney(by: journey.id) {
                journey = updated
            }
        }) {
            // Resumed from the detail screen: finishing just closes this
            // cover and returns here (not to the landing page). The stack is
            // needed because the AR page pushes the preview page internally.
            NavigationStack {
                JourneyARPlacementView(journey: journey, onFlowFinished: {
                    showARPlacement = false
                })
            }
        }
    }
    
    private func publishJourney() {
        journeyService.publishJourney(journey.id)
        if let updated = journeyService.getJourney(by: journey.id) {
            journey = updated
        }
    }
    
    private func deleteJourney() {
        journeyService.deleteJourney(journey.id)
        // Navigation will pop automatically
    }
}

/// Simple QR code display view
struct QRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let journey: Journey
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                Text("Share this QR code")
                    .font(.title2.bold())
                
                Text("Participants scan this to start the journey")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Placeholder QR code
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(radius: 10)
                    
                    Image(systemName: "qrcode")
                        .font(.system(size: 200))
                        .foregroundStyle(.black)
                }
                .frame(width: 300, height: 300)
                .padding()
                
                if journey.qrCodeData != nil {
                    Text("Journey ID: \(journey.id.uuidString.prefix(8))...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    // TODO: Share QR code
                } label: {
                    Label("Share QR Code", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.brandOrange, .brandPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        JourneyDetailView(journey: Journey(
            name: "Museum Tour",
            description: "A guided tour through the exhibits",
            startLatitude: 37.7749,
            startLongitude: -122.4194,
            checkpointIDs: [UUID(), UUID(), UUID()],
            isPublished: true
        ))
    }
}
