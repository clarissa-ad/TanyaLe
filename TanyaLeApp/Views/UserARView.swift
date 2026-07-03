import SwiftUI
import RealityKit
import ARKit
import CoreLocation

struct UserARView: View {
    @StateObject private var locationManager = LocationManager()
    @ObservedObject private var db = MockDatabaseService.shared
    
    @State private var nearbyCheckpoint: Checkpoint?
    @State private var distanceToTarget: CLLocationDistance?
    
    // We use a class to hold our ARView so we can spawn items from SwiftUI
    class ARContainer {
        var view: ARView?
        var hasSpawnedBox = false
    }
    private let arContainer = ARContainer()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            UserARViewContainer(arContainer: arContainer)
                .edgesIgnoringSafeArea(.all)
            
            // HUD showing distance
            VStack {
                if let distance = distanceToTarget, let checkpoint = nearbyCheckpoint {
                    Text("Target: \(checkpoint.title) - \(Int(distance))m away")
                        .font(.headline)
                        .padding()
                        .background(distance < 15 ? Color.green.opacity(0.8) : Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 40)
                } else {
                    Text("Searching for nearby checkpoints...")
                        .font(.caption)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 40)
                }
                Spacer()
            }
            
            // Task Popup when close!
            if let distance = distanceToTarget, distance < 15, let checkpoint = nearbyCheckpoint {
                VStack(alignment: .leading, spacing: 10) {
                    Text("📍 Checkpoint Reached!")
                        .font(.title2)
                        .bold()
                    Text(checkpoint.taskDescription)
                        .font(.body)
                    
                    Button(action: {
                        // Dismiss or complete task logic
                        nearbyCheckpoint = nil
                        distanceToTarget = nil
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
                .animation(.spring(), value: distance)
            }
        }
        .navigationTitle("AR Proximity Camera")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationManager.requestPermission()
        }
        .onReceive(locationManager.$userLocation) { userLoc in
            guard let userLoc = userLoc else { return }
            
            // Simple logic: Find the closest checkpoint
            var closest: Checkpoint? = nil
            var minDistance: CLLocationDistance = .infinity
            
            for cp in db.checkpoints {
                let cpLocation = CLLocation(latitude: cp.latitude, longitude: cp.longitude)
                let distance = userLoc.distance(from: cpLocation)
                if distance < minDistance {
                    minDistance = distance
                    closest = cp
                }
            }
            
            if minDistance < 100 { // Only care if within 100 meters
                nearbyCheckpoint = closest
                distanceToTarget = minDistance
                
                // If we get closer than 15 meters, spawn the 3D object in AR!
                if minDistance < 15 && !arContainer.hasSpawnedBox {
                    spawnARBox()
                    arContainer.hasSpawnedBox = true
                }
            } else {
                nearbyCheckpoint = nil
                distanceToTarget = nil
                arContainer.hasSpawnedBox = false // Reset if we walk away
            }
        }
    }
    
    private func spawnARBox() {
        guard let arView = arContainer.view else { return }
        
        // Spawn it 2 meters in front of where the camera is looking
        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -2.0))
        
        let boxMesh = MeshResource.generateBox(size: 0.3) // 30cm box
        let material = SimpleMaterial(color: .green, isMetallic: true)
        let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
        
        anchor.addChild(boxEntity)
        arView.scene.addAnchor(anchor)
    }
}

struct UserARViewContainer: UIViewRepresentable {
    let arContainer: UserARView.ARContainer
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
        
        arContainer.view = arView
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

#Preview {
    UserARView()
}
