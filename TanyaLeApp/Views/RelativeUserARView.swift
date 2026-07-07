import SwiftUI
import RealityKit
import ARKit
import MapKit
import Combine

struct RelativeUserARView: View {
    private var db = MockDatabaseService.shared
    @State private var viewModel = CitizenARViewModel()
    
    enum MapState {
        case hidden, preview, expanded
    }
    @State private var mapState: MapState = .preview
    /// When set, the bottom half of the screen fills with this emoji.
    @State private var celebrationEmoji: String?
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
                        VStack(alignment: .trailing) {
                            if mapState != .hidden {
                                Map(position: $mapPosition) {
                                    ForEach(db.checkpoints) { cp in
                                        Annotation("", coordinate: cp.coordinate) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 15, height: 15)
                                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        }
                                    }

                                    // AR Blue Dot for Indoor Tracking
                                    if let userLoc = viewModel.arUserLocation {
                                        Annotation("", coordinate: userLoc) {
                                            Circle()
                                                .fill(Color.blue)
                                                .frame(width: 15, height: 15)
                                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                                .shadow(radius: 2)
                                        }
                                    }
                                }
                                .frame(width: mapState == .expanded ? 300 : 120,
                                       height: mapState == .expanded ? 400 : 120)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                                .shadow(radius: 5)
                                .onAppear {
                                    // Snap to origin when map appears
                                    if let origin = db.surveyOrigin {
                                        mapPosition = .region(MKCoordinateRegion(center: origin, span: minimapSpan))
                                    }
                                }
                            }
                            
                            // Floating Toggle Buttons
                            HStack(spacing: 15) {
                                if mapState != .hidden {
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            mapState = (mapState == .preview) ? .expanded : .preview
                                        }
                                    }) {
                                        Image(systemName: mapState == .expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                            .padding(10)
                                            .background(Color.white.opacity(0.9))
                                            .clipShape(Circle())
                                            .shadow(radius: 3)
                                    }
                                    
                                    Button(action: {
                                        if let userLoc = viewModel.arUserLocation {
                                            withAnimation {
                                                mapPosition = .region(MKCoordinateRegion(center: userLoc, span: minimapSpan))
                                            }
                                        }
                                    }) {
                                        Image(systemName: "location.fill")
                                            .padding(10)
                                            .background(Color.white.opacity(0.9))
                                            .clipShape(Circle())
                                            .shadow(radius: 3)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        mapState = (mapState == .hidden) ? .preview : .hidden
                                    }
                                }) {
                                    Image(systemName: mapState == .hidden ? "map.fill" : "eye.slash.fill")
                                        .padding(10)
                                        .background(Color.white.opacity(0.9))
                                        .clipShape(Circle())
                                        .shadow(radius: 3)
                                }
                            }
                            .padding(.top, 5)
                        }
                        .padding()
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
                            Label("Photobooth interaction coming soon", systemImage: "camera")
                                .foregroundStyle(.secondary)
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
        guard let arView = arContainer.view else { return }
        
        for cp in db.checkpoints {
            let position = SIMD3<Float>(cp.relativeX, cp.relativeY, cp.relativeZ)
            let anchor = AnchorEntity(world: position)
            
            let boxMesh = MeshResource.generateBox(size: 0.2)
            let material = SimpleMaterial(color: .green, isMetallic: true)
            let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
            anchor.addChild(boxEntity)

            if cp.hasMCQ || cp.hasEmojiSlider {
                // Interactive survey card floats above the marker box. It gets
                // yawed toward the camera every frame, staying upright like a
                // beacon, and answers are given by tapping the card itself.
                Task { @MainActor in
                    let saveAnswer: (String) -> Void = { answer in
                        MockDatabaseService.shared.saveResponse(checkpointID: cp.id, answer: answer)
                    }
                    let controller: (any ARSurveyBoard)?
                    if cp.hasMCQ {
                        controller = await MCQBoardController.make(for: cp, onSubmit: saveAnswer)
                    } else {
                        controller = await EmojiSliderBoardController.make(for: cp) { answer, chosenEmoji in
                            saveAnswer(answer)
                            showEmojiCelebration(chosenEmoji)
                        }
                    }

                    if let controller {
                        controller.rootEntity.position = [0, 1.0, 0]
                        anchor.addChild(controller.rootEntity)
                        arContainer.faceCameraEntities.append(controller.rootEntity)
                        arContainer.boardControllers.append(controller)
                    }
                }
            } else {
                // No MCQ configured yet: show a floating title label instead.
                let textMesh = MeshResource.generateText(
                    cp.title,
                    extrusionDepth: 0.01,
                    font: .systemFont(ofSize: 0.1),
                    containerFrame: .zero,
                    alignment: .center,
                    lineBreakMode: .byWordWrapping
                )
                let textEntity = ModelEntity(mesh: textMesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
                // Center the text on its holder so the camera-facing rotation
                // pivots around the middle instead of the glyphs' corner.
                textEntity.position = [-textMesh.bounds.center.x, 0, 0]

                let titleHolder = Entity()
                titleHolder.position = [0, 0.25, 0]
                titleHolder.addChild(textEntity)
                boxEntity.addChild(titleHolder)
                arContainer.faceCameraEntities.append(titleHolder)
            }

            arView.scene.addAnchor(anchor)
        }
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
