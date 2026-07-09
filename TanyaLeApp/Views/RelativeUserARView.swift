import SwiftUI
import RealityKit
import ARKit
import MapKit
import Combine

struct RelativeUserARView: View {
    private var db = MockDatabaseService.shared
    @State private var viewModel = CitizenARViewModel()
    
    /// When set, the bottom half of the screen fills with this emoji.
    @State private var celebrationEmoji: String?
    
    // Photobooth state
    @State private var showingImagePicker = false
    @State private var showingGallery = false
    
    // Photo Preview States
    @State private var capturedPhotoForPreview: UIImage?
    @State private var showingPhotoPreview = false
    @State private var selectedImage: UIImage?
    @State private var activeCheckpoint: Checkpoint?
    
    /// Fixed minimap zoom level (max zoom).
    private let minimapSpan = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
    @State private var mapPosition = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -6.200000, longitude: 106.816666),
        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
    ))
    
    class ARContainer {
        var view: ARView?
        var arrowEntity: Entity?
        // Entities that should keep facing the camera (question boards, labels).
        var faceCameraEntities: [Entity] = []
        /// Keeps track of anchors by Checkpoint ID so we can dynamically add items to them
        var checkpointAnchors: [UUID: AnchorEntity] = [:]
        
        var updateSubscription: Cancellable?
        // Interactive survey cards, so taps can be routed to them.
        var boardControllers: [any ARSurveyBoard] = []
    }
    private let arContainer = ARContainer()
    
    var body: some View {
        ZStack {
            // The AR Camera is safely insulated from SwiftUI re-renders!
            RelativeUserARViewContainer(arContainer: arContainer)
                .ignoresSafeArea()
            
            // Aiming Crosshair
            Image(systemName: "plus")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 2)

            // Emoji celebration after submitting an emoji slider
            if let celebrationEmoji {
                EmojiCelebrationView(emoji: celebrationEmoji)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(15)
            }
            
            // Top Right Minimap Preview
            VStack {
                HStack {
                    Spacer()

                    if viewModel.isOriginSet {
                        ARMinimapView(
                            checkpoints: db.checkpoints,
                            userLocation: viewModel.arUserLocation,
                            origin: db.surveyOrigin
                        )
                    }
                }
                Spacer()
            }
            .zIndex(10)
            
            VStack {
                // HUD for Proximity Tracking
                if viewModel.isOriginSet, let dist = viewModel.nearestDistance, let cp = viewModel.nearestCheckpoint {
                    Text("Nearest Task: \(cp.title) - \(String(format: "%.1f", dist))m away")
                        .font(.headline)
                        .padding()
                        .background(dist < 2.0 ? Color.green.opacity(0.8) : Color.black.opacity(0.7))
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                        .padding(.top, 40)
                        .animation(.easeInOut, value: dist)
                } else if viewModel.isOriginSet {
                    Text("Scanning for checkpoints...")
                        .font(.caption)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                        .padding(.top, 40)
                }
                
                Spacer()
                
                if !viewModel.isOriginSet {
                    // Step 1: Simulate scanning the App Clip
                    VStack(spacing: 15) {
                        Text("Citizen: Stand at the exact same physical App Clip and tap below to calibrate.")
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                        
                        Button(action: {
                            if let arView = arContainer.view {
                                // 1. Set the Origin via ViewModel
                                viewModel.setOrigin(arView: arView)
                                
                                // 2. Create the 3D Directional Arrow
                                let cameraAnchor = AnchorEntity(.camera)
                                let wrapper = Entity()
                                wrapper.position = [0, -0.1, -0.2]
                                
                                let mat = SimpleMaterial(color: .yellow, isMetallic: true)
                                let cone = ModelEntity(mesh: MeshResource.generateCone(height: 0.05, radius: 0.02), materials: [mat])
                                cone.transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                                cone.position = [0, 0, -0.025]
                                
                                let cylinder = ModelEntity(mesh: MeshResource.generateCylinder(height: 0.05, radius: 0.005), materials: [mat])
                                cylinder.transform.rotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                                cylinder.position = [0, 0, 0.025]
                                
                                wrapper.addChild(cone)
                                wrapper.addChild(cylinder)
                                cameraAnchor.addChild(wrapper)
                                arView.scene.addAnchor(cameraAnchor)
                                arContainer.arrowEntity = wrapper
                                
                                // 3. Load Checkpoints and start Tracking!
                                loadCheckpoints()
                                viewModel.startTracking(arContainer: arContainer)
                            }
                        }) {
                            Text("Scan App Clip (Sync Origin)")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .cornerRadius(15)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                } else if let dist = viewModel.nearestDistance, dist < 2.0, let cp = viewModel.nearestCheckpoint {
                    // PROXIMITY POPUP CARD
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📍 Checkpoint Reached!")
                            .font(.title2)
                            .bold()

                        if cp.hasMCQ || cp.hasEmojiSlider {
                            // SURVEY: answered on the floating AR card itself
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
                        } else if cp.interactionType == .photobooth {
                            // The 2D "Snap Photo" button has been replaced by the 3D board interaction.
                            // Keeping the Gallery button in the HUD as requested for testing.
                            Button(action: {
                                activeCheckpoint = cp
                                showingGallery = true
                            }) {
                                Label("Gallery", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .foregroundStyle(.white)
                                    .cornerRadius(10)
                            }
                        } else if cp.interactionType == .emojiSlider {
                            Label("Emoji slider needs a question configured", systemImage: "face.smiling")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(cp.taskDescription)
                                .font(.body)

                            Button(action: {
                                print("Task Completed: \(cp.title)")
                            }) {
                                Text("Complete Task")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .foregroundStyle(.white)
                                    .cornerRadius(10)
                            }
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
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            if let cp = activeCheckpoint {
                PhotoboothCaptureView(checkpoint: cp) { image in
                    // Instead of saving instantly, hold it for preview
                    capturedPhotoForPreview = image
                    // Small delay to allow the sheet to dismiss before presenting fullScreenCover
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingPhotoPreview = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingPhotoPreview) {
            if let image = capturedPhotoForPreview, let cp = activeCheckpoint {
                PhotoPreviewView(
                    capturedImage: image,
                    checkpoint: cp,
                    onRetake: {
                        capturedPhotoForPreview = nil
                        showingPhotoPreview = false
                        // Re-open camera after brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showingImagePicker = true
                        }
                    },
                    onExploreMore: {
                         // Finalize the capture
                        MockPhotoService.shared.savePhoto(image: image, forCheckpoint: cp.id)
                        
                        // Dynamically add the new photo into the 3D scene!
                        if let anchor = arContainer.checkpointAnchors[cp.id] {
                            // Find out how many photos already exist to position it correctly
                            let photosCount = MockPhotoService.shared.fetchPhotos(forCheckpoint: cp.id).count
                            
                            Task { @MainActor in
                                if let entity = CheckpointBoardLoader.createPhotoEntity(from: image) {
                                    // Place the floating photos beside the board (starting to the right)
                                    let spacing: Float = 0.5
                                    let xOffset: Float = 0.45 + Float(photosCount - 1) * spacing
                                    entity.position = [xOffset, 0.45 + Float(photosCount % 2) * 0.05, 0]
                                    anchor.addChild(entity)
                                    arContainer.faceCameraEntities.append(entity)
                                }
                            }
                        }
                        
                        capturedPhotoForPreview = nil
                        showingPhotoPreview = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingGallery) {
            if let cp = activeCheckpoint {
                PhotoGalleryView(checkpoint: cp)
            }
        }
        .onChange(of: showingImagePicker) { _, isShowing in
            if isShowing {
                arContainer.view?.session.pause()
            } else {
                if let config = arContainer.view?.session.configuration {
                    arContainer.view?.session.run(config)
                }
            }
        }
        .onDisappear {
            viewModel.stopTracking()
        }
        .navigationTitle("Citizen (Relative AR)")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Fills the bottom half of the screen with the chosen emoji for a few
    /// seconds after an emoji slider submission.
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

    private func loadCheckpoints() {
        CheckpointBoardLoader.load(
            into: arContainer,
            checkpoints: db.checkpoints,
            onEmojiCelebration: showEmojiCelebration,
            onPhotoboothTap: { cp in
                activeCheckpoint = cp
                showingImagePicker = true
            },
            onGalleryTap: { cp in
                activeCheckpoint = cp
                showingGallery = true
            }
        )
    }
}

struct RelativeUserARViewContainer: UIViewRepresentable {
    let arContainer: RelativeUserARView.ARContainer

    func makeCoordinator() -> Coordinator {
        Coordinator(arContainer: arContainer)
    }

    /// Routes taps and drags on the AR view to the interactive survey cards.
    @MainActor
    class Coordinator: NSObject {
        let arContainer: RelativeUserARView.ARContainer
        /// The board currently being dragged (e.g. an emoji slider grab).
        private weak var draggedBoard: (any ARSurveyBoard)?

        init(arContainer: RelativeUserARView.ARContainer) {
            self.arContainer = arContainer
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = arContainer.view else { return }
            let point = recognizer.location(in: arView)
            // Collision-cast so we know both the entity and where on it the
            // tap landed (the slider track needs the position).
            guard let hit = arView.hitTest(point).first else { return }

            let cameraPosition = arView.cameraTransform.translation
            for controller in arContainer.boardControllers {
                if controller.handleTap(on: hit.entity, at: hit.position, cameraPosition: cameraPosition) {
                    return
                }
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let arView = arContainer.view else { return }
            let point = recognizer.location(in: arView)

            switch recognizer.state {
            case .began:
                guard let hit = arView.hitTest(point).first else { return }
                let cameraPosition = arView.cameraTransform.translation
                for controller in arContainer.boardControllers {
                    if controller.beginDrag(on: hit.entity, cameraPosition: cameraPosition) {
                        draggedBoard = controller
                        return
                    }
                }
            case .changed:
                guard let draggedBoard,
                      let ray = arView.ray(through: point) else { return }
                draggedBoard.updateDrag(rayOrigin: ray.origin, rayDirection: ray.direction)
            case .ended, .cancelled, .failed:
                draggedBoard?.endDrag()
                draggedBoard = nil
            default:
                break
            }
        }
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapRecognizer)

        let panRecognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panRecognizer.maximumNumberOfTouches = 1
        arView.addGestureRecognizer(panRecognizer)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.worldAlignment = .gravityAndHeading // Locks Z-axis to True North
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        arContainer.view = arView

        // Rotate the question boards toward the camera every frame, yaw-only,
        // so they stand upright like beacons and stay readable from any side.
        arContainer.updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak arContainer] _ in
            guard let arContainer, let arView = arContainer.view else { return }
            let cameraPosition = arView.cameraTransform.translation
            for entity in arContainer.faceCameraEntities {
                entity.yawToFace(cameraPosition: cameraPosition)
            }
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        // Tear the session down when leaving the screen. Without this, the
        // gesture recognizers keep the old ARView alive (view → recognizer →
        // coordinator → container → view), its session never pauses, and the
        // camera feed appears frozen when the AR screen is reopened.
        uiView.session.pause()
        uiView.gestureRecognizers?.forEach(uiView.removeGestureRecognizer)

        let container = coordinator.arContainer
        container.updateSubscription?.cancel()
        container.updateSubscription = nil
        container.faceCameraEntities = []
        container.boardControllers = []
        container.arrowEntity = nil
        container.view = nil
    }
}

#Preview {
    RelativeUserARView()
}
