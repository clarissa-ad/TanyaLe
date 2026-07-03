import SwiftUI
import RealityKit
import ARKit

struct RelativeUserARView: View {
    @ObservedObject private var db = MockDatabaseService.shared
    
    @State private var isOriginSet = false
    
    class ARContainer {
        var view: ARView?
    }
    private let arContainer = ARContainer()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            RelativeUserARViewContainer(arContainer: arContainer)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                if !isOriginSet {
                    // Step 1: Simulate scanning the App Clip
                    VStack(spacing: 15) {
                        Text("Citizen: Stand at the exact same physical App Clip and tap below to calibrate.")
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        
                        Button(action: {
                            // Reset the world origin
                            if let arView = arContainer.view, let currentTransform = arView.session.currentFrame?.camera.transform {
                                arView.session.setWorldOrigin(relativeTransform: currentTransform)
                                isOriginSet = true
                                
                                // Automatically load all checkpoints!
                                loadCheckpoints()
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
                } else {
                    // HUD
                    Text("All checkpoints loaded! Look around.")
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Citizen (Relative AR)")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func loadCheckpoints() {
        guard let arView = arContainer.view else { return }
        
        for cp in db.checkpoints {
            // Reconstruct the physical position relative to the origin (App Clip)
            let position = SIMD3<Float>(cp.relativeX, cp.relativeY, cp.relativeZ)
            let anchor = AnchorEntity(world: position)
            
            let boxMesh = MeshResource.generateBox(size: 0.2) // 20cm box
            let material = SimpleMaterial(color: .green, isMetallic: true)
            let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
            
            // Add a floating text label above the box
            let textMesh = MeshResource.generateText(
                cp.title,
                extrusionDepth: 0.01,
                font: .systemFont(ofSize: 0.1),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            let textEntity = ModelEntity(mesh: textMesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
            textEntity.position = [0, 0.2, 0] // slightly above the box
            
            boxEntity.addChild(textEntity)
            anchor.addChild(boxEntity)
            arView.scene.addAnchor(anchor)
        }
    }
}

struct RelativeUserARViewContainer: UIViewRepresentable {
    let arContainer: RelativeUserARView.ARContainer
    
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
    RelativeUserARView()
}
