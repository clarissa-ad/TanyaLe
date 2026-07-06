import SwiftUI
import RealityKit
import ARKit

import CoreLocation

struct RelativeMakerARView: View {
    @StateObject private var viewModel = MakerViewModel()
    @StateObject private var locationManager = LocationManager()
    
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
                .foregroundColor(.white)
                .shadow(color: .black, radius: 2)
            
            VStack {
                Spacer()
                
                if !isOriginSet {
                    // Step 1: Simulate scanning the App Clip
                    VStack(spacing: 15) {
                        Text("Stand at the physical App Clip location and tap below to calibrate.")
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        
                        Button(action: {
                            if let arView = arContainer.view {
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
                                    isOriginSet = true

                                } else if let currentTransform = arView.session.currentFrame?.camera.transform {
                                    // 2. Fallback to Camera if pointing at empty sky
                                    var originTransform = matrix_identity_float4x4
                                    originTransform.columns.3 = currentTransform.columns.3
                                    arView.session.setWorldOrigin(relativeTransform: originTransform)
                                    isOriginSet = true
                                }
                                
                                if isOriginSet {
                                    // Lock the Origin GPS!
                                    let loc = locationManager.userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: -6.200000, longitude: 106.816666)
                                    MockDatabaseService.shared.surveyOrigin = loc
                                }
                            }
                        }) {
                            Text("Scan App Clip (Set Origin)")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(15)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                } else {
                    // Step 2: Walk around and aim with crosshair to drop checkpoints
                    Button(action: {
                        if let arView = arContainer.view {
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
                    }) {
                        HStack {
                            Image(systemName: "cube.transparent")
                            Text("Drop Checkpoint Here")
                                .fontWeight(.bold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .foregroundColor(.white)
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
        .navigationTitle("Maker (Relative AR)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: NavigationLink(destination: CheckpointListView()) {
            Image(systemName: "list.bullet")
                .font(.title2)
                .foregroundColor(.blue)
        })
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
//                Form {
//                    CheckpointFormContent(
//                        title: $tempTitle,
//                        taskDescription: $tempDesc,
//                        interactionType: $tempInteractionType,
//                        question: $tempQuestion,
//                        surveyOptions: $tempSurveyOptions,
//                        emojiLeft: $tempEmojiLeft,
//                        emojiRight: $tempEmojiRight
//                    )
//                }
//                .navigationTitle("New Checkpoint")
//                .navigationBarItems(
//                    leading: Button("Cancel") {
//                        showingAddSheet = false
//                    },
//                    trailing: Button("Save") {
//                        if let transform = pendingTransform {
//                            saveCheckpoint(at: transform)
//                        }
//                    }
//                    .disabled(tempTitle.isEmpty)
//                )
            }
        }
    }
    
    private func saveCheckpoint(at position: SIMD3<Float>) {
        guard let arView = arContainer.view else { return }
        
        // Spawn the box visually
        let anchor = AnchorEntity(world: position)
        let boxMesh = MeshResource.generateBox(size: 0.15)
        let material = SimpleMaterial(color: .purple, isMetallic: true)
        let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
        anchor.addChild(boxEntity)
        arView.scene.addAnchor(anchor)
        
        // Save to DB
        viewModel.addCheckpointAt(
            transform: position,
            title: tempTitle,
            description: tempDesc,
            interactionType: tempInteractionType,
            question: tempQuestion.trimmingCharacters(in: .whitespaces),
            surveyOptions: tempSurveyOptions.filter { !$0.isEmpty },
            emojiLeft: tempEmojiLeft,
            emojiRight: tempEmojiRight
        )
        
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
}

struct RelativeMakerARViewContainer: UIViewRepresentable {
    let arContainer: RelativeMakerARView.ARContainer
    
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
}

#Preview {
    RelativeMakerARView()
}
