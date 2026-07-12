//
//  ARWalkView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 06/07/26.
//
import SwiftUI
import RealityKit
import ARKit
import Combine

/// The "walk" step of the citizen flow. A live AR camera with a 2D navigator
/// arrow that points at the nearest checkpoint, a leave-a-message button, and a
/// minimap. Survey checkpoints (MCQ / emoji slider) are answered on floating AR
/// cards, exactly like `RelativeUserARView`.
///
/// This screen is the step *after* the App Clip origin scan, so there is no
/// manual "Scan App Clip" button — it auto-calibrates the world origin as soon
/// as the AR session produces a frame.
struct ARWalkView: View {
    private var db = MockDatabaseService.shared
    private var locationManager = LocationManager.shared
    @State private var viewModel = CitizenARViewModel()
    @State private var aspirationManager = WalkableAspirationManager()
    
    // One AR scene shared by the tracking view model, the survey boards, and the
    // dropped aspiration messages.
    private let arContainer = RelativeUserARView.ARContainer()
    
    /// When set, the bottom half of the screen fills with this emoji.
    @State private var celebrationEmoji: String?
    /// Shows the first-run tutorial card when the screen loads.
    @State private var showTutorial = true

    /// When set, shows the read-only asset detail sheet ("Read more" on a
    /// Like/Dislike card).
    @State private var showingAssetDetail = false
    @State private var presentedAssetId: String?

    
    /// How close (in meters) the citizen must be for the checkpoint card to
    /// show. Shared with the view model so the navigator arrow hides at the
    /// exact distance the card appears.
    private let interactionRadius = CitizenARViewModel.arrivalRadius
    
    /// The checkpoint the citizen is currently close enough to interact with,
    /// or `nil` while they should still be following the navigator arrow.
    /// Keys off the nearest *unanswered* checkpoint: arriving at an
    /// already-answered one shows no card — the arrow (pointing at the next
    /// unanswered checkpoint) stays as the only guidance.
    private var arrivedCheckpoint: Checkpoint? {
        guard let dist = viewModel.nearestUnansweredDistance, dist < interactionRadius else { return nil }
        return viewModel.nearestUnansweredCheckpoint
    }
    
    var body: some View {
        ZStack {
            // Background is a live AR camera (not an image).
            RelativeARViewContainer(arContainer: arContainer)
                .edgesIgnoringSafeArea(.all)
            
            // Top controls: aspiration button (left), minimap (right).
            VStack {
                HStack(alignment: .top) {
                    WalkableAspirationButton(
                        systemName: "bubble.and.pencil",
                        accessibilityLabel: "Leave a message here"
                    ) { text in
                        dropMessage(text)
                    }
                    
                    Spacer()
                    
                    ARMinimapView(
                        checkpoints: db.checkpoints,
                        userLocation: viewModel.arUserLocation,
                        origin: db.surveyOrigin
                    )
                }
                .padding()
                
                Spacer()
            }
            .zIndex(10)
            
            // Bottom-center: the 2D navigator arrow, or the checkpoint card once
            // the user is close enough to interact.
            VStack {
                Spacer()
                
                if let cp = arrivedCheckpoint {
                    arriveatCheckpoint(for: cp)
                }
                // While walking, guidance comes from the 3D Arrow.usdz in the
                // AR scene — CitizenARViewModel.updateTracking() points it at
                // the nearest unanswered checkpoint and hides it once every
                // checkpoint has been answered.
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: arrivedCheckpoint?.id)
            
            // Emoji celebration after submitting an emoji slider.
            if let celebrationEmoji {
                EmojiCelebrationView(emoji: celebrationEmoji)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(15)
            }
            
            // First-run tutorial, dismissed by tapping "Find Lele".
            if showTutorial {
                TutorialPopup {
                    withAnimation { showTutorial = false }
                }
                .transition(.opacity)
                .zIndex(30)
            }
        }
        .onAppear {
            locationManager.requestPermission()
            calibrateWhenReady()
            watchForTrackingDivergence()
        }
        .onDisappear {
            viewModel.stopTracking()
            // Pause the AR session to save resources
            arContainer.view?.session.pause()
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAssetDetail) {
            if let presentedAssetId {
                NavigationStack {
                    AssetDetailView(assetId: presentedAssetId)
                        .navigationBarItems(trailing: Button {
                            showingAssetDetail = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        })
                }
            }
        }
    }

    // MARK: - Subviews

    /// Popup shown when a checkpoint is within reach. Survey answers happen on
    /// the floating AR card itself; this just mirrors the current status.
    @ViewBuilder
    private func checkpointCard(for cp: Checkpoint) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📍 Checkpoint Reached!")
                .font(.title2)
                .bold()

            if cp.hasMCQ || cp.hasEmojiSlider {
                Text(cp.question)
                    .font(.headline)

                if let answer = db.responses[cp.id] {
                    Label("Answered: \(answer)", systemImage: "checkmark.circle.fill")
                        .font(.body.bold())
                        .foregroundStyle(.green)
                } else if cp.hasMCQ {
                    Label("Tap an option on the floating card, then hit Submit", systemImage: "hand.tap")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Tap along the slider on the floating card, then hit Submit", systemImage: "hand.tap")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if cp.hasLikeDislike {
                Text(cp.question)
                    .font(.headline)

                if let votes = db.likeDislikeVotes[cp.id] {
                    Label("\(votes.likes) 👍 · \(votes.dislikes) 👎 so far", systemImage: "chart.bar.fill")
                        .font(.body.bold())
                        .foregroundColor(.green)
                } else {
                    Label("Tap 👍 or 👎 on the floating card", systemImage: "hand.tap")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if cp.interactionType == .photobooth {
                Label("Photobooth interaction coming soon", systemImage: "camera")
                    .foregroundStyle(.secondary)
            } else if cp.interactionType == .emojiSlider {
                Label("Emoji slider needs a question configured", systemImage: "face.smiling")
                    .foregroundStyle(.secondary)
            } else if cp.interactionType == .likedislike {
                Label("Like/Dislike needs a question configured", systemImage: "hand.thumbsup")
                    .foregroundStyle(.secondary)
            } else {
                Text(cp.taskDescription)
                    .font(.body)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 20)
        .padding(20)
        .transition(.move(edge: .bottom))
        .animation(.spring(), value: viewModel.nearestDistance)
    }

    
    // MARK: - AR setup
    /// Waits for the AR session to be ready, then calibrates the world origin,
    /// drops the checkpoints, and starts proximity tracking. Replaces the manual
    /// "Scan App Clip" button since this screen runs after that step.
    private func calibrateWhenReady() {
        Task { @MainActor in
            // Poll for up to ~20s until the session tracks normally. Waiting
            // for .normal (instead of just the first frame) matters twice
            // over: the floor raycast in setOrigin can actually succeed, and
            // .gravityAndHeading has finished swinging the world into compass
            // alignment before we drop world-anchored checkpoints into it.
            // The long budget covers the camera-permission prompt on first
            // launch.
            for _ in 0..<200 {
                if let arView = arContainer.view,
                   let frame = arView.session.currentFrame,
                   case .normal = frame.camera.trackingState {
                    guard !viewModel.isOriginSet else { return }
                    viewModel.setOrigin(arView: arView)
                    // 3D navigator arrow: floats ahead of the camera and is
                    // aimed by updateTracking() at the nearest unanswered
                    // checkpoint.
                    ARArrowLoader.attach(to: arContainer)
                    CheckpointBoardLoader.load(
                        into: arContainer,
                        checkpoints: db.checkpoints,
                        onEmojiCelebration: showEmojiCelebration,
                        onShowAssetDetail: showAssetDetail,
                        onPhotoboothTap: { _ in },
                        onGalleryTap: { _ in }
                    )
                    viewModel.startTracking(arContainer: arContainer)
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            print("ARWalkView: AR tracking never reached .normal — no checkpoints or arrow were loaded")
        }
    }

    /// Watches for the AR session diverging into NaN camera poses (the
    /// "RETransformComponentSetLocalSRT contains NaN" console flood — world
    /// tracking has fallen apart and nothing can render). When detected,
    /// wipes the scene, restarts tracking from scratch, and re-runs
    /// calibration so the world rebuilds instead of staying invisible.
    private func watchForTrackingDivergence() {
        Task { @MainActor in
            while let arView = arContainer.view {
                try? await Task.sleep(for: .seconds(1))
                // Check the FULL pose matrix — the failure seen in the wild is
                // NaN in the rotation columns while the translation stays
                // valid, which silently blanks all rendering.
                guard let camera = arView.session.currentFrame?.camera,
                      Self.containsNaN(camera.transform) else { continue }

                print("ARWalkView: camera pose contains NaN (rotation diverged) — resetting session and rebuilding the AR world.")
                viewModel.stopTracking()
                arView.scene.anchors.removeAll()
                arContainer.faceCameraEntities = []
                arContainer.boardControllers = []
                arContainer.arrowEntity = nil
                viewModel.isOriginSet = false

                if let config = arView.session.configuration {
                    arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
                }
                calibrateWhenReady()
                watchForTrackingDivergence() // re-arm for the fresh session
                return
            }
        }
    }

    private static func containsNaN(_ m: simd_float4x4) -> Bool {
        for column in [m.columns.0, m.columns.1, m.columns.2, m.columns.3] {
            if column.x.isNaN || column.y.isNaN || column.z.isNaN || column.w.isNaN {
                return true
            }
        }
        return false
    }

}



extension ARWalkView {
    // MARK: - Subviews
    
    /// A 2D arrow (replacing the old 3D cone entity) rotated to point at the
    /// nearest checkpoint from the camera's point of view.
    private var navigatorArrow: some View {
        Image("arrow_navigator")
            .resizable()
            .scaledToFit()
            .frame(width: 120)
            .rotationEffect(.radians(viewModel.arrowHeading ?? 0))
            .padding(.bottom, 60)
            .animation(.easeInOut(duration: 0.2), value: viewModel.arrowHeading)
            .allowsHitTesting(false)
    }
    
    // Arriving at a certain checkpoint: the bottom card whose title, body, and
    // icon react to whether the interaction has been answered yet.
    private func arriveatCheckpoint(for cp: Checkpoint) -> some View {
        CheckpointReachedCard(checkpoint: cp, answer: db.responses[cp.id])
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // Dropping aspiration on exact location where user is standing
    private func dropMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let arView = arContainer.view,
              let frame = arView.session.currentFrame else { return }
        
        // Camera transform = where the phone is; feet are ~1.4m below it.
        let cam = frame.camera.transform
        let camPos = SIMD3<Float>(cam.columns.3.x, cam.columns.3.y, cam.columns.3.z)
        let standing = SIMD3<Float>(camPos.x, camPos.y - 1.4, camPos.z)
        
        let coordinate = locationManager.userLocation?.coordinate
        aspirationManager.add(
            WalkableAspiration(
                message: trimmed,
                latitude: coordinate?.latitude ?? 0,
                longitude: coordinate?.longitude ?? 0,
                relativeX: standing.x,
                relativeY: standing.y,
                relativeZ: standing.z
            )
        )
        
        let anchor = AnchorEntity(world: standing)
        arView.scene.addAnchor(anchor)
        
        Task { @MainActor in
            guard let controller = await MessageBoardController.make(message: trimmed) else {
                print("ARWalkView: MessageBoardController.make returned nil — aspiration card not rendered")
                return
            }
            controller.rootEntity.position = [0, 1.2, 0]
            anchor.addChild(controller.rootEntity)
            arContainer.faceCameraEntities.append(controller.rootEntity)
            arContainer.boardControllers.append(controller)
        }
    }
    
    
    // Fills the bottom half of the screen with emoji
    private func showEmojiCelebration(_ emoji: String) {
        withAnimation {
            celebrationEmoji = emoji
        }
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation {
                celebrationEmoji = nil
            }
        }
    }

    /// Presents the read-only asset detail sheet for "Read more" on a
    /// Like/Dislike card.
    private func showAssetDetail(_ assetId: String) {
        presentedAssetId = assetId
        showingAssetDetail = true
    }
}

#Preview {
    ARWalkView()
}
