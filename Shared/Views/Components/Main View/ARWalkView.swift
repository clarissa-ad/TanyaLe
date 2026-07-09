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
    
    /// How close (in meters) the citizen must be for the checkpoint card to show.
    private let interactionRadius: Float = 1.0
    
    /// The checkpoint the citizen is currently close enough to interact with,
    /// or `nil` while they should still be following the navigator arrow.
    private var arrivedCheckpoint: Checkpoint? {
        guard let dist = viewModel.nearestDistance, dist < interactionRadius else { return nil }
        return viewModel.nearestCheckpoint
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
                } else if viewModel.nearestCheckpoint != nil {
                    navigatorArrow
                }
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
        }
        .onDisappear {
            viewModel.stopTracking()
            // Pause the AR session to save resources
            arContainer.view?.session.pause()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - AR setup
    /// Waits for the AR session to be ready, then calibrates the world origin,
    /// drops the checkpoints, and starts proximity tracking. Replaces the manual
    /// "Scan App Clip" button since this screen runs after that step.
    private func calibrateWhenReady() {
        Task { @MainActor in
            // Poll for up to ~5s until the session produces a frame.
            for _ in 0..<50 {
                if let arView = arContainer.view, arView.session.currentFrame != nil {
                    guard !viewModel.isOriginSet else { return }
                    viewModel.setOrigin(arView: arView)
                    CheckpointBoardLoader.load(
                        into: arContainer,
                        checkpoints: db.checkpoints,
                        onEmojiCelebration: showEmojiCelebration
                    )
                    viewModel.startTracking(arContainer: arContainer)
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
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
            guard let controller = await MessageBoardController.make(message: trimmed) else { return }
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
}

#Preview {
    ARWalkView()
}
