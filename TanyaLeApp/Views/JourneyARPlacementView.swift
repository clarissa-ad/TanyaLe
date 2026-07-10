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
    // Uses the maker-side ARContainer so we get the 3D surface reticle
    // (reticleGroup + per-frame raycast) from RelativeMakerARViewContainer.
    @State private var arContainer = ARContainer()
    @State private var hasSetAROrigin = false
    @State private var showCheckpointForm = false
    @State private var newCheckpointPosition: SIMD3<Float>?
    @State private var showCheckpointList = false
    @State private var showPreview = false
    /// True while a Like/Dislike asset is previewed live in the scene, waiting
    /// for Pak RT to drag-rotate it and confirm or cancel.
    @State private var isConfirmingPlacement = false
    /// The just-saved checkpoint whose asset is being rotated. Already stored
    /// at rotation 0 — confirm writes back its `assetRotationY`.
    @State private var pendingCheckpoint: Checkpoint?

    var journeyService = JourneyService.shared
    var checkpointService = MockDatabaseService.shared
    
    var body: some View {
        ZStack {
            // AR Camera View — includes the 3D surface reticle
            RelativeMakerARViewContainer(arContainer: arContainer)
                .edgesIgnoringSafeArea(.all)

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
                    if hasSetAROrigin && !isConfirmingPlacement {
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
                if isConfirmingPlacement {
                    placementConfirmPanel
                } else if hasSetAROrigin {
                    ZStack {
                        // Tap to place button (centered)
                        Button {
                            placeCheckpoint()
                        } label: {
                            VStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 50))
                                Text("Place Checkpoint 3")
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
            // Tap-to-reset: hides the reticle until the next surface hit
            arContainer.onTap = {
                arContainer.reticleGroup?.isEnabled = false
                arContainer.isOnSurface = false
            }
        }
        .sheet(isPresented: $showCheckpointForm) {
            if let position = newCheckpointPosition {
                CheckpointFormSheet(
                    position: position,
                    journey: journey,
                    onSave: { checkpoint in
                        beginPlacementOrRender(checkpoint)
                    }
                )
            }
        }
        .sheet(isPresented: $showCheckpointList, onDismiss: refreshCheckpoints) {
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
        // RelativeMakerARViewContainer already configures and runs the AR
        // session (plane detection, coaching overlay, reticle update loop),
        // so we only need to set the origin once tracking has warmed up.
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
        // Read the journey fresh from the service — the local @State copy's
        // checkpointIDs go stale (checkpoints are associated on the service,
        // not our value-type snapshot).
        let fresh = journeyService.getJourney(by: journey.id) ?? journey
        let existingCheckpoints = checkpointService.checkpoints.filter {
            fresh.checkpointIDs.contains($0.id)
        }

        renderCheckpoints(existingCheckpoints)
    }

    /// Rebuilds the whole AR scene from the current stored checkpoints. Called
    /// after the edit sheet closes so edits/deletes show up — e.g. swapping a
    /// Like/Dislike asset from tempat sampah to kandang ayam — instead of
    /// leaving the stale marker from the first render.
    private func refreshCheckpoints() {
        guard hasSetAROrigin else { return }
        CheckpointBoardLoader.clear(from: arContainer)
        loadExistingCheckpoints()
    }
    
    // MARK: - Checkpoint Placement
    
    private func placeCheckpoint() {
        guard let arView = arContainer.view else { return }

        // Prefer the reticle's confirmed surface hit so the checkpoint lands
        // exactly where the reticle is shown.
        if let reticlePosition = arContainer.reticlePosition {
            newCheckpointPosition = reticlePosition
            showCheckpointForm = true
        } else {
            // Fallback: place 1.5m in front of the camera — the same distance
            // the reticle floats at while no surface is detected.
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

            newCheckpointPosition = cameraPos + (normalize(forward) * 1.5)
            showCheckpointForm = true
        }
    }
    
    /// Renders checkpoints into the AR scene exactly like the citizen view —
    /// the real placed 3D asset with an interactive Like/Dislike vote card,
    /// MCQ / emoji-slider / photobooth boards for surveys, or the Lele marker
    /// with a floating title otherwise. Uses the shared `CheckpointBoardLoader`
    /// so Pak RT previews precisely what a citizen will see, faced-to-camera
    /// and tappable. Callbacks are no-ops and `recordResponses: false` keeps
    /// the preview from writing votes/answers into the store.
    private func renderCheckpoints(_ checkpoints: [Checkpoint]) {
        CheckpointBoardLoader.load(
            into: arContainer,
            checkpoints: checkpoints,
            onEmojiCelebration: { _ in },
            onShowAssetDetail: { _ in },
            onPhotoboothTap: { _ in },
            onGalleryTap: { _ in },
            recordResponses: false,
            submitEnabled: false
        )
    }
    
    private func finishPlacement() {
        // The service already holds the up-to-date journey (checkpoints are
        // associated as they're saved); writing our local snapshot back here
        // would erase them. Just open the pre-publish review.
        showPreview = true
    }

    // MARK: - Like/Dislike asset rotation

    /// After a checkpoint is saved: for a Like/Dislike checkpoint with a
    /// placeable asset, start the drag-to-rotate preview; otherwise render it
    /// straight away.
    private func beginPlacementOrRender(_ checkpoint: Checkpoint) {
        if checkpoint.interactionType == .likedislike,
           let assetId = checkpoint.selectedAssetId,
           AssetPlacementConfig.config(forAssetId: assetId) != nil,
           let arView = arContainer.view {
            beginAssetPlacementPreview(checkpoint: checkpoint, assetId: assetId, in: arView)
        } else {
            renderCheckpoints([checkpoint])
        }
    }

    /// Drops the asset alone into the scene and switches on the confirm/cancel
    /// panel. Pak RT drags to spin it — the rotation itself is handled by the
    /// shared `AssetPlacementController` via the container's pan gesture; this
    /// view only orchestrates the preview lifecycle. Nothing is finalized until
    /// `confirmPlacement()`.
    private func beginAssetPlacementPreview(checkpoint: Checkpoint, assetId: String, in arView: ARView) {
        let position = SIMD3<Float>(checkpoint.relativeX, checkpoint.relativeY, checkpoint.relativeZ)
        let anchor = AnchorEntity(world: position)
        arView.scene.addAnchor(anchor)
        arContainer.pendingPlacementAnchor = anchor
        pendingCheckpoint = checkpoint

        Task { @MainActor in
            do {
                arContainer.activePlacement = try await AssetPlacementController.make(assetId: assetId, anchor: anchor)
                isConfirmingPlacement = true
            } catch {
                // Model failed to load — don't strand the flow. Drop the empty
                // anchor and just render the checkpoint at its default rotation.
                print("AssetPlacementController failed to load \(assetId): \(error)")
                endPlacementPreview()
                renderCheckpoints([checkpoint])
            }
        }
    }

    /// Writes the dragged rotation onto the checkpoint and renders the final
    /// asset + vote card in its place.
    private func confirmPlacement() {
        guard var checkpoint = pendingCheckpoint else { return }
        checkpoint.assetRotationY = arContainer.activePlacement?.rotationY ?? 0
        checkpointService.updateCheckpoint(checkpoint)
        endPlacementPreview()
        renderCheckpoints([checkpoint])
    }

    /// Keeps the checkpoint at its default rotation (it's already saved) and
    /// renders it as-is.
    private func cancelPlacement() {
        let checkpoint = pendingCheckpoint
        endPlacementPreview()
        if let checkpoint { renderCheckpoints([checkpoint]) }
    }

    /// Tears down the live preview: removes the preview-only asset anchor and
    /// clears the placement state.
    private func endPlacementPreview() {
        arContainer.pendingPlacementAnchor?.removeFromParent()
        arContainer.pendingPlacementAnchor = nil
        arContainer.activePlacement = nil
        isConfirmingPlacement = false
        pendingCheckpoint = nil
    }

    private var placementConfirmPanel: some View {
        VStack(spacing: 12) {
            Text("Geser untuk memutar aset")
                .font(.footnote)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .cornerRadius(20)

            HStack(spacing: 16) {
                Button(action: cancelPlacement) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }

                Button(action: confirmPlacement) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("Confirm").fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [.brandPurple, .brandPurpleDark],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .padding(.bottom, 30)
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
    @State private var selectedAssetId: String?
    @State private var showingAssetPicker = false

    @State private var promptPhotoID: String? = nil
    @State private var showingImagePicker = false
    
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
                    emojiRight: $emojiRight,
                    promptPhotoID: $promptPhotoID,
                    showingImagePicker: $showingImagePicker,
                    selectedAssetId: $selectedAssetId,
                    showingAssetPicker: $showingAssetPicker
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
            .sheet(isPresented: $showingAssetPicker) {
                AssetPickerView(selectedAssetId: $selectedAssetId)
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
            promptPhotoID: promptPhotoID,
            selectedAssetId: selectedAssetId,
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
