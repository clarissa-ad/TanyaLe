import Foundation
import Combine
import RealityKit
import ARKit
import CoreLocation

class CitizenARViewModel: ObservableObject {
    @Published var isOriginSet = false
    @Published var nearestDistance: Float?
    @Published var nearestCheckpoint: Checkpoint?
    @Published var arUserLocation: CLLocationCoordinate2D?
    
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
        // Run a lightweight timer loop (5 FPS)
        trackingTimer = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTracking(arContainer: arContainer)
            }
    }
    
    func stopTracking() {
        trackingTimer?.cancel()
        trackingTimer = nil
    }
    
    private func updateTracking(arContainer: RelativeUserARView.ARContainer) {
        guard let arView = arContainer.view,
              let currentFrame = arView.session.currentFrame else { return }
        
        let camTransform = currentFrame.camera.transform
        let camPos = SIMD3<Float>(camTransform.columns.3.x, camTransform.columns.3.y, camTransform.columns.3.z)
        
        // --- 1. Calculate AR Map Coordinates (Indoor Tracking) ---
        if let origin = MockDatabaseService.shared.surveyOrigin {
            let latOffset = Double(camPos.z) / 111111.0
            let lonOffset = Double(camPos.x) / 111111.0
            arUserLocation = CLLocationCoordinate2D(latitude: origin.latitude + latOffset, longitude: origin.longitude + lonOffset)
        }
        
        // --- 2. Calculate Nearest Checkpoint Proximity ---
        guard isOriginSet else { return }
        
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
