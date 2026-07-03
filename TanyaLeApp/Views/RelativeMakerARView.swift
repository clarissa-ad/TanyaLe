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
    @State private var pendingTransform: SIMD3<Float>?
    
    class ARContainer {
        var view: ARView?
    }
    private let arContainer = ARContainer()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            RelativeMakerARViewContainer(arContainer: arContainer)
                .edgesIgnoringSafeArea(.all)
            
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
                            if let arView = arContainer.view, let currentTransform = arView.session.currentFrame?.camera.transform {
                                arView.session.setWorldOrigin(relativeTransform: currentTransform)
                                isOriginSet = true
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
                    // Step 2: Walk around and drop checkpoints
                    Button(action: {
                        if let arView = arContainer.view, let cameraTransform = arView.session.currentFrame?.camera.transform {
                            // Calculate a position 1.5m in front of the current camera position
                            var translation = matrix_identity_float4x4
                            translation.columns.3.z = -1.5
                            let newTransform = matrix_multiply(cameraTransform, translation)
                            
                            pendingTransform = SIMD3<Float>(newTransform.columns.3.x, newTransform.columns.3.y, newTransform.columns.3.z)
                            showingAddSheet = true
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
        .sheet(isPresented: $showingAddSheet) {
            NavigationView {
                Form {
                    TextField("Checkpoint Title", text: $tempTitle)
                    TextField("Description", text: $tempDesc)
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
        
        // Spawn the box visually
        let anchor = AnchorEntity(world: position)
        let boxMesh = MeshResource.generateBox(size: 0.15)
        let material = SimpleMaterial(color: .purple, isMetallic: true)
        let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
        anchor.addChild(boxEntity)
        arView.scene.addAnchor(anchor)
        
        // Save to DB
        let loc = locationManager.userLocation ?? CLLocation(latitude: 0, longitude: 0)
        viewModel.addCheckpointAt(transform: position, location: loc, title: tempTitle, description: tempDesc)
        
        // Reset sheet state
        tempTitle = ""
        tempDesc = ""
        showingAddSheet = false
    }
}

struct RelativeMakerARViewContainer: UIViewRepresentable {
    let arContainer: RelativeMakerARView.ARContainer
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        arContainer.view = arView
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

#Preview {
    RelativeMakerARView()
}
