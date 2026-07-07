import Foundation
import Observation
import Combine
import RealityKit
import ARKit
import CoreLocation

@Observable
class CitizenARViewModel {
    var isOriginSet = false
    var nearestDistance: Float?
    var nearestCheckpoint: Checkpoint?
    var arUserLocation: CLLocationCoordinate2D?

    // Internal timer handle; views never read it, so keep it out of tracking.
    @ObservationIgnored private var trackingTimer: AnyCancellable?
    
    func setOrigin(arView: ARView) {
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)

        // Try to shoot a laser to find the physical spot on the floor/wall
        if let query = arView.makeRaycastQuery(from: screenCenter, allowing: .estimatedPlane, alignment: .any),
           let result = arView.session.raycast(query).first {
            arView.session.setWorldOrigin(relativeTransform: translationOnly(result.worldTransform))
            isOriginSet = true
        } else if let currentTransform = arView.session.currentFrame?.camera.transform {
            // Fallback to camera if pointing at the sky
            arView.session.setWorldOrigin(relativeTransform: translationOnly(currentTransform))
            isOriginSet = true
        }
    }

    /// Strips the rotation from a transform, keeping only its position.
    /// Applying a rotated transform to `setWorldOrigin` would tilt the whole
    /// world's axes (e.g. when the raycast hits a wall or the camera is
    /// tilted), making anchored content lean or lie flat and breaking the
    /// gravity + heading alignment shared with the Maker session.
    private func translationOnly(_ transform: simd_float4x4) -> simd_float4x4 {
        var result = matrix_identity_float4x4
        result.columns.3 = transform.columns.3
        return result
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
