import Foundation
import Combine
import RealityKit
import ARKit

class CitizenARViewModel: ObservableObject {
    @Published var isOriginSet = false
    @Published var nearestDistance: Float?
    @Published var nearestCheckpoint: Checkpoint?
    
    private var trackingTimer: AnyCancellable?
    
    func setOrigin(arView: ARView) {
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        // Try to shoot a laser to find the physical spot on the floor/wall
        if let query = arView.makeRaycastQuery(from: screenCenter, allowing: .estimatedPlane, alignment: .any),
           let result = arView.session.raycast(query).first {
            arView.session.setWorldOrigin(relativeTransform: result.worldTransform)
            isOriginSet = true
        } else if let currentTransform = arView.session.currentFrame?.camera.transform {
            // Fallback to camera if pointing at the sky
            arView.session.setWorldOrigin(relativeTransform: currentTransform)
            isOriginSet = true
        }
    }
    
    func startTracking(arContainer: RelativeUserARView.ARContainer) {
        // Run tracking at 5 FPS to save battery and prevent UI lag
        trackingTimer = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.calculateProximity(arContainer: arContainer)
            }
    }
    
    func stopTracking() {
        trackingTimer?.cancel()
        trackingTimer = nil
    }
    
    private func calculateProximity(arContainer: RelativeUserARView.ARContainer) {
        guard isOriginSet, let arView = arContainer.view, let camTransform = arView.session.currentFrame?.camera.transform else { return }
        
        let camPos = SIMD3<Float>(camTransform.columns.3.x, camTransform.columns.3.y, camTransform.columns.3.z)
        
        var minDistance: Float = .infinity
        var closestCP: Checkpoint? = nil
        
        let checkpoints = MockDatabaseService.shared.checkpoints
        
        for cp in checkpoints {
            let cpPos = SIMD3<Float>(cp.relativeX, cp.relativeY, cp.relativeZ)
            let distance = simd_distance(camPos, cpPos)
            if distance < minDistance {
                minDistance = distance
                closestCP = cp
            }
        }
        
        if minDistance < 100 {
            nearestDistance = minDistance
            nearestCheckpoint = closestCP
            
            // Point the arrow at the closest checkpoint!
            if let arrow = arContainer.arrowEntity, let cp = closestCP {
                let cpPos = SIMD3<Float>(cp.relativeX, cp.relativeY, cp.relativeZ)
                arrow.look(at: cpPos, from: arrow.position(relativeTo: nil), relativeTo: nil)
                arrow.isEnabled = true
            }
        } else {
            nearestDistance = nil
            nearestCheckpoint = nil
            arContainer.arrowEntity?.isEnabled = false
        }
    }
}
