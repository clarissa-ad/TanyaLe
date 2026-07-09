import SwiftUI

/// Pre-publish review shown when the maker taps "Done" in the AR placement
/// view: journey details plus every checkpoint, with a final Publish button.
struct JourneyPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let journey: Journey
    /// Called after publishing so the presenting AR screen can close too.
    var onPublished: () -> Void = {}

    var journeyService = JourneyService.shared
    var checkpointService = MockDatabaseService.shared

    private var checkpoints: [Checkpoint] {
        checkpointService.checkpoints.filter { journey.checkpointIDs.contains($0.id) }
    }

    private var canPublish: Bool {
        journey.hasStartPoint && !checkpoints.isEmpty
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Journey")) {
                    LabeledContent("Name", value: journey.name)

                    if !journey.description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(journey.description)
                        }
                    }

                    LabeledContent("Created", value: journey.createdDate.formatted(date: .long, time: .omitted))
                }

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

                Section(header: Text("Checkpoints (\(checkpoints.count))")) {
                    if checkpoints.isEmpty {
                        Text("No checkpoints yet — go back and place at least one.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(checkpoints) { checkpoint in
                            CheckpointRowView(checkpoint: checkpoint)
                        }
                    }
                }

                Section(footer: publishFooter) {
                    Button(action: publish) {
                        Text("Publish Journey")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient.brandPurpleButton()
                                    .opacity(canPublish ? 1 : 0.4),
                                in: Capsule()
                            )
                            .foregroundColor(.white)
                    }
                    .disabled(!canPublish)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Preview Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep Editing") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var publishFooter: some View {
        if !canPublish {
            Text("A start point and at least one checkpoint are needed before publishing.")
        }
    }

    private func publish() {
        journeyService.publishJourney(journey.id)
        dismiss()
        onPublished()
    }
}

#Preview {
    JourneyPreviewView(journey: Journey(
        name: "Museum Tour",
        description: "Explore the science exhibits",
        startLatitude: 37.7749,
        startLongitude: -122.4194,
        checkpointIDs: [UUID()]
    ))
}
