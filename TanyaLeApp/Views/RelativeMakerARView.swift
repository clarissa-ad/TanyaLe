import SwiftUI
import RealityKit
import ARKit

import CoreLocation

struct RelativeMakerARView: View {
    // Journey integration
    @State var journey: Journey
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel = MakerViewModel()
    var locationManager = LocationManager.shared
    
    @State private var isOriginSet = false
    @State private var showingAddSheet = false
    @State private var tempTitle = ""
    @State private var tempDesc = ""
    @State private var tempInteractionType: Checkpoint.InteractionType = .none
    @State private var tempQuestion: String = ""
    @State private var tempSurveyOptions: [String] = []
    @State private var tempEmojiLeft: String = ""
    @State private var tempEmojiRight: String = ""
    @State private var pendingTransform: SIMD3<Float>?
    
    var journeyService = JourneyService.shared
    var db = MockDatabaseService.shared
    
    class ARContainer {
        var view: ARView?
    }
    private let arContainer = ARContainer()
    
    var body: some View {
        ZStack {
            RelativeMakerARViewContainer(arContainer: arContainer)
                .edgesIgnoringSafeArea(.all)
            
            // Aiming Crosshair (Always visible so you can aim the origin too!)
            Image(systemName: "plus")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 2)
            
            VStack {
                Spacer()
                
                if !isOriginSet {
                    // Step 1: Set AR origin at the start point
                    VStack(spacing: 15) {
                        Text("Point your camera at the starting point location and tap below to set the AR origin.")
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                        
                        Button(action: {
                            setAROrigin()
                        }) {
                            Text("Set AR Origin Here")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(15)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                } else {
                    // Step 2: Walk around and aim with crosshair to drop checkpoints
                    Button(action: {
                        aimToPlaceCheckpoint()
                    }) {
                        HStack {
                            Image(systemName: "cube.transparent")
                            Text("Drop Checkpoint Here")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .onAppear {
            locationManager.requestPermission()
        }
        .navigationTitle(journey.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: CheckpointListView()) {
                    Image(systemName: "list.bullet")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                Form {
                    CheckpointFormContent(
                        title: $tempTitle,
                        taskDescription: $tempDesc,
                        interactionType: $tempInteractionType,
                        question: $tempQuestion,
                        surveyOptions: $tempSurveyOptions,
                        emojiLeft: $tempEmojiLeft,
                        emojiRight: $tempEmojiRight
                    )
                }
                .navigationTitle("New Checkpoint")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingAddSheet = false
                    },
                    trailing: Button("Save") {
                        if let transform = pendingTransform {
                            saveCheckpoint(at: transform)
                        }
                    }
                    .disabled(tempTitle.isEmpty)
                )
            }
        }
    }
    
    private func saveCheckpoint(at position: SIMD3<Float>) {
        guard let arView = arContainer.view else { return }
        
        // Spawn the Lele checkpoint model visually. Loading a .usdz is async, so
        // we build it in a Task and fall back to a purple box if it can't load.
        let anchor = AnchorEntity(world: position)
        arView.scene.addAnchor(anchor)
        Task { @MainActor in
            let marker: Entity
            if let model = try? await Entity(named: "Lele_Checkpoint") {
                marker = model
                // The .usdz is ~2.4 m tall with a centred origin; scale it down
                // and rest it on the anchor so it doesn't swallow the camera.
                CheckpointBoardLoader.normalizeMarker(marker)
            } else {
                let boxMesh = MeshResource.generateBox(size: 0.15)
                let material = SimpleMaterial(color: .purple, isMetallic: true)
                marker = ModelEntity(mesh: boxMesh, materials: [material])
            }
            anchor.addChild(marker)
        }
        
        // Save to DB
        let checkpoint = viewModel.addCheckpointAt(
            transform: position,
            title: tempTitle,
            description: tempDesc,
            interactionType: tempInteractionType,
            question: tempQuestion.trimmingCharacters(in: .whitespaces),
            surveyOptions: tempSurveyOptions.filter { !$0.isEmpty },
            emojiLeft: tempEmojiLeft,
            emojiRight: tempEmojiRight
        )
        
        // Associate checkpoint with journey
        journeyService.addCheckpoint(checkpoint.id, to: journey.id)
        
        // Reset sheet state
        tempTitle = ""
        tempDesc = ""
        tempInteractionType = .none
        tempQuestion = ""
        tempSurveyOptions = []
        tempEmojiLeft = ""
        tempEmojiRight = ""
        showingAddSheet = false
    }
    
    // MARK: - Journey Integration Helpers
    
    private func setAROrigin() {
        guard let arView = arContainer.view else { return }
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        // Only the position is used for the origin — keeping the
        // rotation would tilt the world's axes (wall hits, tilted
        // camera) and break the shared gravity/heading alignment.
        // 1. Try to shoot a raycast to find a physical origin anchor (e.g. on the wall/floor)
        if let query = arView.makeRaycastQuery(from: screenCenter, allowing: .estimatedPlane, alignment: .any),
           let result = arView.session.raycast(query).first {

            var originTransform = matrix_identity_float4x4
            originTransform.columns.3 = result.worldTransform.columns.3
            arView.session.setWorldOrigin(relativeTransform: originTransform)
            
            // Save AR origin to journey
            journey.arOriginX = result.worldTransform.columns.3.x
            journey.arOriginY = result.worldTransform.columns.3.y
            journey.arOriginZ = result.worldTransform.columns.3.z
            journeyService.updateJourney(journey)
            
            isOriginSet = true

        } else if let currentTransform = arView.session.currentFrame?.camera.transform {
            // 2. Fallback to Camera if pointing at empty sky
            var originTransform = matrix_identity_float4x4
            originTransform.columns.3 = currentTransform.columns.3
            arView.session.setWorldOrigin(relativeTransform: originTransform)
            
            // Save AR origin to journey
            journey.arOriginX = currentTransform.columns.3.x
            journey.arOriginY = currentTransform.columns.3.y
            journey.arOriginZ = currentTransform.columns.3.z
            journeyService.updateJourney(journey)
            
            isOriginSet = true
        }
        
        if isOriginSet {
            // Also set the legacy DB origin for backward compatibility
            db.surveyOrigin = CLLocationCoordinate2D(
                latitude: journey.startLatitude,
                longitude: journey.startLongitude
            )
        }
    }
    
    private func aimToPlaceCheckpoint() {
        guard let arView = arContainer.view else { return }
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        // 1. Try to shoot a raycast at the physical world
        if let query = arView.makeRaycastQuery(from: screenCenter, allowing: .estimatedPlane, alignment: .any),
           let result = arView.session.raycast(query).first {
            
            // Successful Raycast! Snap exactly to the physical object
            let transform = result.worldTransform
            pendingTransform = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            showingAddSheet = true
            
        } else if let cameraTransform = arView.session.currentFrame?.camera.transform {
            // 2. Fallback: If aiming at empty space, drop 1.5m floating in front
            var translation = matrix_identity_float4x4
            translation.columns.3.z = -1.5
            let newTransform = matrix_multiply(cameraTransform, translation)
            
            pendingTransform = SIMD3<Float>(newTransform.columns.3.x, newTransform.columns.3.y, newTransform.columns.3.z)
            showingAddSheet = true
        }
    }
}

struct RelativeMakerARViewContainer: UIViewRepresentable {
    let arContainer: RelativeMakerARView.ARContainer

    func makeCoordinator() -> Coordinator {
        Coordinator(arContainer: arContainer)
    }

    /// Keeps a handle to the container so the session can be torn down when
    /// the view is dismantled.
    @MainActor
    class Coordinator {
        let arContainer: RelativeMakerARView.ARContainer

        init(arContainer: RelativeMakerARView.ARContainer) {
            self.arContainer = arContainer
        }
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.worldAlignment = .gravityAndHeading // Locks Z-axis to True North
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        arContainer.view = arView
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        // Pause the camera session when leaving so reopening the AR screen
        // starts from a clean state instead of a frozen feed.
        uiView.session.pause()
        coordinator.arContainer.view = nil
    }
}

#Preview {
    RelativeMakerARView(journey: Journey(name: "Test Journey"))
}
