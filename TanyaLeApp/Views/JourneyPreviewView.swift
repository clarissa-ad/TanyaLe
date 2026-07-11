import SwiftUI
import MapKit

/// Final step of the creation flow (pushed, step 4 of 4): "Preview Survey".
/// Shows the journey details and every checkpoint, with Publish and
/// Save-as-draft actions. Publishing pushes the journey info screen (details,
/// status, checkpoints, QR code).
struct JourneyPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let journey: Journey
    /// Called when the flow is finished (published or saved as draft); the
    /// landing page pops the whole creation stack in one state change.
    var onDone: () -> Void = {}

    /// Set after publishing; pushes the journey info screen.
    @State private var publishedJourney: Journey?
    /// Shows the start point on a map (the "Area" row's button).
    @State private var showAreaMap = false

    var journeyService = JourneyService.shared
    var checkpointService = MockDatabaseService.shared

    private var checkpoints: [Checkpoint] {
        checkpointService.checkpoints.filter { journey.checkpointIDs.contains($0.id) }
    }

    private var canPublish: Bool {
        journey.hasStartPoint && !checkpoints.isEmpty
    }

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Preview Survey")
                        .font(.largeTitle.bold())
                        .padding(.top, 12)

                    startPointSection

                    checkpointsSection
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .safeAreaInset(edge: .top) {
                header
                    .padding(.bottom, 8)
                    .background(Color(.systemGray6))
            }
            .safeAreaInset(edge: .bottom) {
                actionCard
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAreaMap) {
            areaMapSheet
        }
        .navigationDestination(item: $publishedJourney) { published in
            // Journey info: details, published status, checkpoints, QR.
            JourneyDetailView(journey: published)
                .navigationBarBackButtonHidden()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onDone()
                        }
                    }
                }
        }
    }

    // MARK: - Header (back button + step dots)

    private var header: some View {
        ZStack {
            // Step 4 of 4 in the creation flow.
            HStack(spacing: 12) {
                ForEach(0..<4) { _ in
                    Circle()
                        .fill(Color.brandPurple)
                        .frame(width: 10, height: 10)
                }
            }

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 48, height: 48)
                        .background(Color.white, in: Circle())
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                // Keep the chevron black instead of the app's accent tint.
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Start point card

    private var startPointSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start Point")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Title")
                        .font(.headline)
                    Spacer()
                    Text(journey.name)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Description")
                        .font(.subheadline.weight(.semibold))
                    Text(journey.description.isEmpty ? "—" : journey.description)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Divider()

                HStack {
                    Text("Created")
                        .font(.headline)
                    Spacer()
                    Text(journey.createdDate.formatted(date: .long, time: .omitted))
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Text("Area")
                        .font(.headline)
                    Spacer()
                    Button {
                        showAreaMap = true
                    } label: {
                        Image(systemName: "map")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!journey.hasStartPoint)
                    .accessibilityLabel("View start point on map")
                }
            }
            .padding(20)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    // MARK: - Checkpoints card

    private var checkpointsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Checkpoints (\(checkpoints.count))")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 14) {
                if checkpoints.isEmpty {
                    Text("No checkpoints yet — go back and place at least one.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(checkpoints) { checkpoint in
                        // Full row: question, interaction badge, emoji pair —
                        // same component as the edit list.
                        CheckpointRowView(checkpoint: checkpoint)

                        if checkpoint.id != checkpoints.last?.id {
                            Divider()
                        }
                    }
                }
            }
            // A VStack only grows as wide as its widest child; stretch the
            // card to full width even when a single short row is inside.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    // MARK: - Bottom actions

    private var actionCard: some View {
        VStack(spacing: 14) {
            Button(action: publish) {
                Text("Publish Survey")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.brandPurple.opacity(canPublish ? 1 : 0.4), in: Capsule())
            }
            .disabled(!canPublish)

            Button(action: saveAsDraft) {
                Text("Save as draft")
                    .font(.headline)
                    .foregroundStyle(Color.brandPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().stroke(Color.brandPurple, lineWidth: 1.5))
            }

            Text("Drafts are kept under My Surveys, so you\ncan finish and publish later.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(
            Color.white,
            in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32)
        )
    }

    // MARK: - Area map

    private var areaMapSheet: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: journey.startCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        ))) {
            Marker(journey.name, coordinate: journey.startCoordinate)
                .tint(Color.brandPurple)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Actions

    private func publish() {
        journeyService.publishJourney(journey.id)
        publishedJourney = journeyService.getJourney(by: journey.id)
    }

    /// The journey is already stored unpublished, so "saving" a draft just
    /// closes the creation flow; it stays listed under My Journeys → Drafts.
    private func saveAsDraft() {
        onDone()
    }
}

#Preview {
    NavigationStack {
        JourneyPreviewView(journey: Journey(
            name: "RT Malaka Jaya",
            description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec euismod est quis gravida accumsan. Integer id orci fermentum.",
            startLatitude: -6.2,
            startLongitude: 106.816666,
            checkpointIDs: [UUID()]
        ))
    }
}
