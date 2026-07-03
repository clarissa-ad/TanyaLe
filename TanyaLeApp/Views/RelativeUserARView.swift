import SwiftUI
import RealityKit
import ARKit

struct RelativeUserARView: View {
    @ObservedObject private var db = MockDatabaseService.shared
    @StateObject private var viewModel = CitizenARViewModel()
    
    class ARContainer {
        var view: ARView?
        var arrowEntity: Entity?
    }
    private let arContainer = ARContainer()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // The AR Camera is safely insulated from SwiftUI re-renders!
            RelativeUserARViewContainer(arContainer: arContainer)
                .edgesIgnoringSafeArea(.all)
            
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
            
            let textMesh = MeshResource.generateText(
                cp.title,
                extrusionDepth: 0.01,
                font: .systemFont(ofSize: 0.1),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            let textEntity = ModelEntity(mesh: textMesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
            textEntity.position = [0, 0.2, 0]
            
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
