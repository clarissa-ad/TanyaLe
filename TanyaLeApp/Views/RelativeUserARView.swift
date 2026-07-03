import SwiftUI
import RealityKit
import ARKit
import MapKit
import Combine

struct RelativeUserARView: View {
    @ObservedObject private var db = MockDatabaseService.shared
    @StateObject private var viewModel = CitizenARViewModel()
    
    enum MapState {
        case hidden, preview, expanded
    }
    @State private var mapState: MapState = .preview
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -6.200000, longitude: 106.816666),
        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001) // Max zoom
    )
    
    class ARContainer {
        var view: ARView?
        var arrowEntity: Entity?
        // Entities that should keep facing the camera (question boards, labels).
        var faceCameraEntities: [Entity] = []
        var updateSubscription: Cancellable?
    }
    private let arContainer = ARContainer()
    
    var body: some View {
        ZStack {
            // The AR Camera is safely insulated from SwiftUI re-renders!
            RelativeUserARViewContainer(arContainer: arContainer)
                .edgesIgnoringSafeArea(.all)
            
            // Aiming Crosshair
            Image(systemName: "plus")
                .font(.system(size: 30, weight: .light))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 2)
            
            // Top Right Minimap Preview
            VStack {
                HStack {
                    Spacer()
                    
                    if viewModel.isOriginSet {
                        VStack(alignment: .trailing) {
                            if mapState != .hidden {
                                Map(coordinateRegion: $mapRegion, annotationItems: db.checkpoints) { cp in
                                    MapAnnotation(coordinate: cp.coordinate) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 15, height: 15)
                                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    }
                                }
                                .frame(width: mapState == .expanded ? 300 : 120, 
                                       height: mapState == .expanded ? 400 : 120)
                                .cornerRadius(15)
                                .shadow(radius: 5)
                                .overlay(
                                    // Custom AR Blue Dot for Indoor Tracking
                                    Group {
                                        if let userLoc = viewModel.arUserLocation {
                                            GeometryReader { proxy in
                                                let mapCenter = mapRegion.center
                                                let span = mapRegion.span
                                                
                                                // Convert coordinates to screen points based on region
                                                // This is a rough estimation for the minimap preview
                                                let xOffset = (userLoc.longitude - mapCenter.longitude) / span.longitudeDelta * Double(proxy.size.width)
                                                let yOffset = (mapCenter.latitude - userLoc.latitude) / span.latitudeDelta * Double(proxy.size.height)
                                                
                                                Circle()
                                                    .fill(Color.blue)
                                                    .frame(width: 15, height: 15)
                                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                                    .shadow(radius: 2)
                                                    .position(x: proxy.size.width / 2 + CGFloat(xOffset),
                                                              y: proxy.size.height / 2 + CGFloat(yOffset))
                                                    .animation(.linear(duration: 0.2), value: userLoc.latitude)
                                            }
                                        }
                                    }
                                )
                                .onAppear {
                                    // Snap to origin when map appears
                                    if let origin = db.surveyOrigin {
                                        mapRegion.center = origin
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
                                                mapRegion.center = userLoc
                                            }
                                        }
                                    }) {
                                        Image(systemName: "location.fill")
                                            .padding(10)
                                            .background(Color.white.opacity(0.9))
                                            .clipShape(Circle())
                                            .shadow(radius: 3)
                                            .foregroundColor(.blue)
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
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 40)
                        .animation(.easeInOut, value: dist)
                } else if viewModel.isOriginSet {
                    Text("Scanning for checkpoints...")
                        .font(.caption)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
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
                            .foregroundColor(.white)
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
                                .foregroundColor(.white)
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

                        if cp.hasMCQ {
                            // MCQ SURVEY: answer the question shown on the AR board
                            Text(cp.question)
                                .font(.headline)

                            if let answer = db.responses[cp.id] {
                                Label("Answered: \(answer)", systemImage: "checkmark.circle.fill")
                                    .font(.body.bold())
                                    .foregroundColor(.green)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(cp.surveyOptions, id: \.self) { option in
                                        Button(action: {
                                            db.saveResponse(checkpointID: cp.id, answer: option)
                                        }) {
                                            Text(option)
                                                .frame(maxWidth: .infinity)
                                                .padding(10)
                                                .background(Color.blue.opacity(0.1))
                                                .foregroundColor(.blue)
                                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue, lineWidth: 1))
                                        }
                                    }
                                }
                            }
                        } else if cp.interactionType == .photobooth {
                            Label("Photobooth interaction coming soon", systemImage: "camera")
                                .foregroundColor(.secondary)
                        } else if cp.interactionType == .emojiSlider {
                            Label("Emoji slider interaction coming soon", systemImage: "face.smiling")
                                .foregroundColor(.secondary)
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
                                    .foregroundColor(.white)
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
    
    private func loadCheckpoints() {
        guard let arView = arContainer.view else { return }
        
        for cp in db.checkpoints {
            let position = SIMD3<Float>(cp.relativeX, cp.relativeY, cp.relativeZ)
            let anchor = AnchorEntity(world: position)
            
            let boxMesh = MeshResource.generateBox(size: 0.2)
            let material = SimpleMaterial(color: .green, isMetallic: true)
            let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
            anchor.addChild(boxEntity)

            if let board = MCQBoardEntity.make(for: cp) {
                // Question board floats above the marker box. It gets yawed
                // toward the camera every frame, staying upright like a beacon.
                board.position = [0, 0.55, 0]
                anchor.addChild(board)
                arContainer.faceCameraEntities.append(board)
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
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
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
}

#Preview {
    RelativeUserARView()
}
