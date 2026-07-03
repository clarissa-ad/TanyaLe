import SwiftUI
import RealityKit
import ARKit
import Combine

struct RelativeUserARView: View {
    @ObservedObject private var db = MockDatabaseService.shared
    
    @State private var isOriginSet = false
    @State private var nearestDistance: Float?
    @State private var nearestCheckpoint: Checkpoint?
    
    class ARContainer {
        var view: ARView?
    }
    private let arContainer = ARContainer()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            RelativeUserARViewContainer(arContainer: arContainer)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // HUD for Proximity Tracking
                if isOriginSet, let dist = nearestDistance, let cp = nearestCheckpoint {
                    Text("Nearest Task: \(cp.title) - \(String(format: "%.1f", dist))m away")
                        .font(.headline)
                        .padding()
                        .background(dist < 2.0 ? Color.green.opacity(0.8) : Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 40)
                        .animation(.easeInOut, value: dist)
                } else if isOriginSet {
                    Text("Scanning for checkpoints...")
                        .font(.caption)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 40)
                }
                
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
                } else if let dist = nearestDistance, dist < 2.0, let cp = nearestCheckpoint {
                    // PROXIMITY POPUP CARD
                    VStack(alignment: .leading, spacing: 10) {
                        Text("📍 Checkpoint Reached!")
                            .font(.title2)
                            .bold()
                        Text(cp.taskDescription)
                            .font(.body)
                        
                        Button(action: {
                            // Logic to complete the task
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
                    .animation(.spring(), value: nearestDistance)
                }
            }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            calculateProximity()
        }
        .navigationTitle("Citizen (Relative AR)")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func loadCheckpoints() {
        guard let arView = arContainer.view else { return }
        
        for cp in db.checkpoints {
            let position = SIMD3<Float>(cp.relativeX, cp.relativeY, cp.relativeZ)
            let anchor = AnchorEntity(world: position)
            
            let boxMesh = MeshResource.generateBox(size: 0.2) // 20cm box
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
            textEntity.position = [0, 0.2, 0] // slightly above the box
            
            boxEntity.addChild(textEntity)
            anchor.addChild(boxEntity)
            arView.scene.addAnchor(anchor)
        }
    }
    
    private func calculateProximity() {
        guard isOriginSet, let arView = arContainer.view, let camTransform = arView.session.currentFrame?.camera.transform else { return }
        
        // Extract camera position (relative to origin)
        let camPos = SIMD3<Float>(camTransform.columns.3.x, camTransform.columns.3.y, camTransform.columns.3.z)
        
        var minDistance: Float = .infinity
        var closestCP: Checkpoint? = nil
        
        for cp in db.checkpoints {
            let cpPos = SIMD3<Float>(cp.relativeX, cp.relativeY, cp.relativeZ)
            let distance = simd_distance(camPos, cpPos)
            if distance < minDistance {
                minDistance = distance
                closestCP = cp
            }
        }
        
        if minDistance < 100 { // Only care if within 100 meters
            nearestDistance = minDistance
            nearestCheckpoint = closestCP
        } else {
            nearestDistance = nil
            nearestCheckpoint = nil
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
