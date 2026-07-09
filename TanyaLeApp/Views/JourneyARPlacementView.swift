//
//  JourneyARPlacementView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 08/07/26.
//

import SwiftUI
import ARKit
import RealityKit

/// AR view for placing checkpoints within a journey context.
/// First step: Sets AR world origin at the start point.
/// Subsequent steps: Place checkpoints by aiming crosshair and tapping.
struct JourneyARPlacementView: View {
    @Environment(\.dismiss) private var dismiss
    @State var journey: Journey
    /// Called when the creation flow ends (published or saved as draft).
    /// The presenter decides how far to unwind — e.g. the journey-creation
    /// flow dismisses all the way back to the landing page, while resuming a
    /// draft from the detail screen just closes this cover.
    var onFlowFinished: () -> Void = {}

    @State private var viewModel = MakerViewModel()
    @State private var arContainer = RelativeUserARView.ARContainer()
    @State private var hasSetAROrigin = false
    @State private var showCheckpointForm = false
    @State private var newCheckpointPosition: SIMD3<Float>?
    @State private var showCheckpointList = false
    @State private var showPreview = false
    
    var journeyService = JourneyService.shared
    var checkpointService = MockDatabaseService.shared
    
    var body: some View {
        ZStack {
            // AR Camera View
            RelativeARViewContainer(arContainer: arContainer)
                .edgesIgnoringSafeArea(.all)
            
            // Crosshair (only show after AR origin is set)
            if hasSetAROrigin {
                Image(systemName: "plus")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
            
            // Top bar: instructions on the left, Edit Checkpoints on the right
            VStack {
                HStack(alignment: .top) {
                    if !hasSetAROrigin {
                        Text("Setting AR World Origin...")
                            .font(.headline)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                    }
//                    else {
//                        VStack(alignment: .leading, spacing: 4) {
//                            Text("Aim & Tap to Place")
//                                .font(.headline)
//                            Text("\(checkpointService.checkpoints.filter { journey.checkpointIDs.contains($0.id) }.count) checkpoints")
//                                .font(.caption)
//                        }
//                        .padding()
//                        .background(.ultraThinMaterial)
//                        .cornerRadius(10)
//                    }

                    Spacer()

                    // Edit checkpoints (top right)
                    if hasSetAROrigin {
                        Button {
                            showCheckpointList = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                    .font(.title2)
                                Text("Edit")
                                    .font(.caption)
                            }
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 60)

                Spacer()

                // Bottom Controls
                if hasSetAROrigin {
                    ZStack {
                        // Tap to place button (centered)
                        Button {
                            placeCheckpoint()
                        } label: {
                            VStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 50))
                                Text("Place Checkpoint")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.brandPurple,.brandPurpleDark],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }

                        // Done button (trailing)
                        HStack {
                            Spacer()

                            Button {
                                finishPlacement()
                            } label: {
                                VStack {
                                    Image(systemName: "checkmark.circle")
                                        .font(.title2)
//                                    Text("Done")
//                                        .font(.caption)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupARSession()
        }
        .sheet(isPresented: $showCheckpointForm) {
            if let position = newCheckpointPosition {
                CheckpointFormSheet(
                    position: position,
                    journey: journey,
                    onSave: { checkpoint in
                        addCheckpointToScene(checkpoint)
                    }
                )
            }
        }
        .sheet(isPresented: $showCheckpointList) {
            JourneyCheckpointListView(journey: journey)
        }
        .sheet(isPresented: $showPreview) {
            // Read the journey fresh from the service — checkpoints added via
            // the form sheet update the service copy, not our local @State.
            JourneyPreviewView(journey: journeyService.getJourney(by: journey.id) ?? journey) {
                // Published or drafted: let the presenter unwind the flow.
                onFlowFinished()
            }
        }
    }
    
    // MARK: - AR Setup
    
    private func setupARSession() {
        guard let arView = arContainer.view else { return }
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.worldAlignment = .gravityAndHeading
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        // Wait a moment for AR to initialize, then set origin
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            setAROrigin()
        }
    }
    
    private func setAROrigin() {
        guard let arView = arContainer.view,
              let frame = arView.session.currentFrame else { return }
        
        // Use raycast or camera position as origin
        let cameraTransform = frame.camera.transform
        let origin = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        // Save the AR origin. Mutate the *service's* copy of the journey, not
        // our local snapshot — writing the snapshot back would wipe checkpoint
        // associations added since it was taken.
        var fresh = journeyService.getJourney(by: journey.id) ?? journey
        fresh.arOriginX = origin.x
        fresh.arOriginY = origin.y
        fresh.arOriginZ = origin.z
        journeyService.updateJourney(fresh)
        journey = fresh

        // Mark as set
        hasSetAROrigin = true

        // Load existing checkpoints if any
        loadExistingCheckpoints()
    }

    private func loadExistingCheckpoints() {
        let existingCheckpoints = checkpointService.checkpoints.filter {
            journey.checkpointIDs.contains($0.id)
        }
        
        for checkpoint in existingCheckpoints {
            addCheckpointToScene(checkpoint)
        }
    }
    
    // MARK: - Checkpoint Placement
    
    private func placeCheckpoint() {
        guard let arView = arContainer.view else { return }
        
        // Raycast from center of screen
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        // Try raycast first
        if let result = arView.raycast(from: screenCenter, allowing: .estimatedPlane, alignment: .any).first {
            newCheckpointPosition = SIMD3<Float>(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )
            showCheckpointForm = true
        } else {
            // Fallback: Place 2m in front of camera
            guard let frame = arView.session.currentFrame else { return }
            let transform = frame.camera.transform
            let forward = SIMD3<Float>(
                -transform.columns.2.x,
                -transform.columns.2.y,
                -transform.columns.2.z
            )
            let cameraPos = SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            
            newCheckpointPosition = cameraPos + (normalize(forward) * 2.0)
            showCheckpointForm = true
        }
    }
    
    private func addCheckpointToScene(_ checkpoint: Checkpoint) {
        guard let arView = arContainer.view else { return }
        
        // Create purple cube marker
        let mesh = MeshResource.generateBox(size: 0.2)
        let material = SimpleMaterial(color: .purple, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        
        // Position at checkpoint location
        entity.position = SIMD3<Float>(
            checkpoint.relativeX,
            checkpoint.relativeY,
            checkpoint.relativeZ
        )
        
        // Add to scene
        let anchor = AnchorEntity(world: entity.position)
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)
    }
    
    private func finishPlacement() {
        // The service already holds the up-to-date journey (checkpoints are
        // associated as they're saved); writing our local snapshot back here
        // would erase them. Just open the pre-publish review.
        showPreview = true
    }
}

// MARK: - Checkpoint Form Sheet

struct CheckpointFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let position: SIMD3<Float>
    let journey: Journey
    let onSave: (Checkpoint) -> Void
    
    @State private var title = ""
    @State private var taskDescription = ""
    @State private var interactionType: Checkpoint.InteractionType = .none
    @State private var question = ""
    @State private var surveyOptions: [String] = []
    @State private var emojiLeft = ""
    @State private var emojiRight = ""
    
    var journeyService = JourneyService.shared
    var checkpointService = MockDatabaseService.shared
    
    var body: some View {
        NavigationView {
            Form {
                CheckpointFormContent(
                    title: $title,
                    taskDescription: $taskDescription,
                    interactionType: $interactionType,
                    question: $question,
                    surveyOptions: $surveyOptions,
                    emojiLeft: $emojiLeft,
                    emojiRight: $emojiRight
                )
            }
            .dismissKeyboardOnTap()
            .navigationTitle("New Checkpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCheckpoint()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func saveCheckpoint() {
        // Create checkpoint with position
        let checkpoint = Checkpoint(
            title: title,
            taskDescription: taskDescription,
            interactionType: interactionType,
            question: question.isEmpty ? "" : question,
            surveyOptions: surveyOptions.isEmpty ? [] : surveyOptions,
            emojiLeft: emojiLeft.isEmpty ? "😡" : emojiLeft,
            emojiRight: emojiRight.isEmpty ? "😍" : emojiRight,
            latitude: 0, // GPS will be calculated relative to journey start
            longitude: 0,
            relativeX: position.x,
            relativeY: position.y,
            relativeZ: position.z
        )
        
        // Save to database
        checkpointService.saveCheckpoint(checkpoint)
        
        // Associate with journey. The service is the single source of truth —
        // readers must fetch the journey by ID rather than trusting local
        // value-type copies, which go stale.
        journeyService.addCheckpoint(checkpoint.id, to: journey.id)

        // Callback to add to scene
        onSave(checkpoint)
        
        dismiss()
    }
}

// MARK: - Journey Checkpoint List

struct JourneyCheckpointListView: View {
    @Environment(\.dismiss) private var dismiss
    let journey: Journey

    var journeyService = JourneyService.shared
    var checkpointService = MockDatabaseService.shared

    /// `Journey` is a value type, so the passed-in copy's `checkpointIDs` can
    /// be stale (e.g. checkpoints added by the form sheet update the service,
    /// not the caller's snapshot). Always re-read the association from the
    /// service — @Observable also keeps this list live as checkpoints change.
    private var currentJourney: Journey {
        journeyService.getJourney(by: journey.id) ?? journey
    }

    var checkpoints: [Checkpoint] {
        checkpointService.checkpoints.filter { currentJourney.checkpointIDs.contains($0.id) }
    }

    var body: some View {
        NavigationView {
            List {
                if checkpoints.isEmpty {
                    Text("No checkpoints yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(checkpoints) { checkpoint in
                        NavigationLink {
                            CheckpointEditView(checkpoint: checkpoint)
                        } label: {
                            CheckpointRowView(checkpoint: checkpoint)
                        }
                    }
                    .onDelete(perform: deleteCheckpoints)
                }
            }
            .navigationTitle("Edit Checkpoints")
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

    private func deleteCheckpoints(at offsets: IndexSet) {
        for index in offsets {
            let checkpoint = checkpoints[index]
            checkpointService.deleteCheckpoint(checkpoint.id)
            journeyService.removeCheckpoint(checkpoint.id, from: journey.id)
        }
    }
}

/// One checkpoint row: title, description, and a summary of the configured
/// interaction (question, option count, emoji pair) so edits are visible in
/// the list immediately after saving.
/// Shared by the edit list and the pre-publish preview.
struct CheckpointRowView: View {
    let checkpoint: Checkpoint

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(checkpoint.title)
                .font(.headline)

            if !checkpoint.taskDescription.isEmpty {
                Text(checkpoint.taskDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if !checkpoint.question.isEmpty,
               checkpoint.interactionType == .mcq || checkpoint.interactionType == .emojiSlider {
                Label(checkpoint.question, systemImage: "questionmark.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if checkpoint.interactionType != .none {
                HStack(spacing: 8) {
                    Text(checkpoint.interactionType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .cornerRadius(4)

                    switch checkpoint.interactionType {
                    case .mcq:
                        let count = checkpoint.surveyOptions.filter { !$0.isEmpty }.count
                        Text("\(count) options")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .emojiSlider:
                        Text("\(checkpoint.emojiLeft) ⟷ \(checkpoint.emojiRight)")
                            .font(.caption)
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }
}

#Preview {
    JourneyARPlacementView(journey: Journey(name: "Test Journey"))
}
