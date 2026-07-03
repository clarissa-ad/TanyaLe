import SwiftUI
import RealityKit
import ARKit

struct RelativeMakerARView: View {
    @StateObject private var viewModel = MakerViewModel()
    
    @State private var isOriginSet = false
    
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
                            // In a real app, this happens automatically when the App Clip is scanned.
                            // For this prototype, we just reset the world origin to exactly where the camera is right now.
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
                        dropCheckpoint()
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
        .navigationTitle("Maker (Relative AR)")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func dropCheckpoint() {
        guard let arView = arContainer.view else { return }
        
        // Spawn it 1.5 meters in front of the camera
        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -1.5))
        
        let boxMesh = MeshResource.generateBox(size: 0.15)
        let material = SimpleMaterial(color: .purple, isMetallic: true)
        let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
        
        anchor.addChild(boxEntity)
        arView.scene.addAnchor(anchor)
        
        // Save the physical offset relative to the App Clip!
        let position = anchor.position
        viewModel.addCheckpointAt(transform: position)
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
