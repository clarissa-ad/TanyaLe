import Foundation
import Observation
import Combine
import RealityKit
import ARKit
import CoreLocation
import UIKit

@Observable
class CitizenARViewModel {
    var isOriginSet = false
    var nearestDistance: Float?
    var nearestCheckpoint: Checkpoint?
    var arUserLocation: CLLocationCoordinate2D?
    /// Clockwise screen-space rotation (radians) for a 2D navigator arrow so it
    /// points at the nearest checkpoint. `nil` when there's nothing to point at.
    var arrowHeading: Double?

    // Internal timer handle; views never read it, so keep it out of tracking.
    @ObservationIgnored private var trackingTimer: AnyCancellable?

    // MARK: - Start gate (walk to the beacon before the AR world builds)

    enum StartGatePhase {
        /// Waiting for the (simulated) QR scan.
        case idle
        /// Gate running but no GPS fix acquired yet.
        case findingLocation
        /// User is outside the start radius — walk toward the beacon.
        case walkToStart
        /// Inside the radius — hold-still countdown running.
        case dwelling
        /// Gate passed; the AR world is being built.
        case ready
    }

    /// How close (meters) the user must be to the start point.
    static let startRadius: Double = 2.0
    /// How long (seconds) they must stay inside the radius.
    static let dwellDuration: TimeInterval = 3.0

    var startGatePhase: StartGatePhase = .idle
    var distanceToStart: Double?
    /// 0...1 progress of the hold-still countdown.
    var dwellProgress: Double = 0

    @ObservationIgnored private var gateTimer: AnyCancellable?
    @ObservationIgnored private var dwellStartedAt: Date?

    /// Starts polling GPS against the journey start point. Shows a green
    /// beacon in AR at the start point; once the user stays within
    /// `startRadius` for `dwellDuration`, calls `onReady` exactly once.
    func beginStartGate(
        startPoint: CLLocationCoordinate2D,
        locationManager: LocationManager,
        arContainer: RelativeUserARView.ARContainer,
        onReady: @escaping () -> Void
    ) {
        startGatePhase = .findingLocation
        gateTimer = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStartGate(
                    startPoint: startPoint,
                    locationManager: locationManager,
                    arContainer: arContainer,
                    onReady: onReady
                )
            }
    }

    func cancelStartGate(arContainer: RelativeUserARView.ARContainer) {
        gateTimer?.cancel()
        gateTimer = nil
        dwellStartedAt = nil
        dwellProgress = 0
        distanceToStart = nil
        startGatePhase = .idle
        removeBeacon(arContainer: arContainer)
    }

    private func updateStartGate(
        startPoint: CLLocationCoordinate2D,
        locationManager: LocationManager,
        arContainer: RelativeUserARView.ARContainer,
        onReady: @escaping () -> Void
    ) {
        guard let location = locationManager.userLocation else {
            startGatePhase = .findingLocation
            return
        }

        let start = CLLocation(latitude: startPoint.latitude, longitude: startPoint.longitude)
        let distance = location.distance(from: start)
        distanceToStart = distance
        updateBeacon(arContainer: arContainer, userCoordinate: location.coordinate, startPoint: startPoint)

        if distance <= Self.startRadius {
            let startedAt = dwellStartedAt ?? Date()
            dwellStartedAt = startedAt
            let elapsed = Date().timeIntervalSince(startedAt)
            dwellProgress = min(elapsed / Self.dwellDuration, 1)
            startGatePhase = .dwelling

            if elapsed >= Self.dwellDuration {
                gateTimer?.cancel()
                gateTimer = nil
                startGatePhase = .ready
                removeBeacon(arContainer: arContainer)
                onReady()
            }
        } else {
            // Left the circle — the countdown starts over next time they enter.
            dwellStartedAt = nil
            dwellProgress = 0
            startGatePhase = .walkToStart
        }
    }

    /// Places (or moves) the green start beacon in the AR world. Because the
    /// session runs with `.gravityAndHeading`, world axes are compass-aligned
    /// even before calibration: +X is east and -Z is true north, so the GPS
    /// offset between the user and the start point maps directly into meters.
    private func updateBeacon(
        arContainer: RelativeUserARView.ARContainer,
        userCoordinate: CLLocationCoordinate2D,
        startPoint: CLLocationCoordinate2D
    ) {
        guard let arView = arContainer.view,
              let camTransform = arView.session.currentFrame?.camera.transform else { return }

        let metersPerDegree = 111_111.0
        let dNorth = (startPoint.latitude - userCoordinate.latitude) * metersPerDegree
        let dEast = (startPoint.longitude - userCoordinate.longitude) * metersPerDegree * cos(userCoordinate.latitude * .pi / 180)

        let camPos = SIMD3<Float>(camTransform.columns.3.x, camTransform.columns.3.y, camTransform.columns.3.z)
        // Drop the beacon to roughly floor level (camera is held ~1.4 m up).
        let target = SIMD3<Float>(camPos.x + Float(dEast), camPos.y - 1.4, camPos.z - Float(dNorth))

        if let anchor = arContainer.beaconAnchor {
            // Ease toward the target so GPS jitter doesn't make the beacon jump.
            anchor.position = simd_mix(anchor.position, target, SIMD3<Float>(repeating: 0.15))
        } else {
            let anchor = AnchorEntity(world: target)
            anchor.addChild(Self.makeBeacon())
            arView.scene.addAnchor(anchor)
            arContainer.beaconAnchor = anchor
        }
    }

    /// A green light pillar with a disc marking the start radius on the floor.
    private static func makeBeacon() -> Entity {
        let beacon = Entity()
        let green = UIColor.systemGreen

        let disc = ModelEntity(
            mesh: .generateCylinder(height: 0.02, radius: Float(startRadius)),
            materials: [SimpleMaterial(color: green.withAlphaComponent(0.35), isMetallic: false)]
        )
        beacon.addChild(disc)

        let pillar = ModelEntity(
            mesh: .generateCylinder(height: 12, radius: 0.25),
            materials: [SimpleMaterial(color: green.withAlphaComponent(0.5), isMetallic: false)]
        )
        pillar.position.y = 6
        beacon.addChild(pillar)

        return beacon
    }

    private func removeBeacon(arContainer: RelativeUserARView.ARContainer) {
        arContainer.beaconAnchor?.removeFromParent()
        arContainer.beaconAnchor = nil
    }

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

            if let cp = closestCP {
                let cpPos = SIMD3<Float>(cp.relativeX, cp.relativeY, cp.relativeZ)

                // Point the 3D arrow (RelativeUserARView) at the closest checkpoint.
                if let arrow = arContainer.arrowEntity {
                    arrow.look(at: cpPos, from: arrow.position(relativeTo: nil), relativeTo: nil)
                    arrow.isEnabled = true
                }

                // Screen-space heading for the 2D arrow (ARWalkView).
                arrowHeading = Self.screenHeading(from: camTransform, to: cpPos)
            }
        } else {
            nearestDistance = nil
            nearestCheckpoint = nil
            arrowHeading = nil
            arContainer.arrowEntity?.isEnabled = false
        }
    }

    /// Angle (radians, clockwise) to rotate an up-pointing 2D arrow so it aims
    /// at `target` from the camera's point of view. Screen-up maps to the
    /// camera's forward direction and screen-right to the camera's right, both
    /// flattened to the horizontal plane so the arrow reads like a compass.
    private static func screenHeading(from cam: simd_float4x4, to target: SIMD3<Float>) -> Double {
        let camPos = SIMD3<Float>(cam.columns.3.x, cam.columns.3.y, cam.columns.3.z)

        func flatten(_ v: SIMD4<Float>) -> SIMD3<Float> { SIMD3<Float>(v.x, 0, v.z) }
        let forward = flatten(-cam.columns.2)          // camera looks down -Z
        let right = flatten(cam.columns.0)             // camera +X
        let toTarget = SIMD3<Float>(target.x - camPos.x, 0, target.z - camPos.z)

        guard simd_length(forward) > 1e-4,
              simd_length(right) > 1e-4,
              simd_length(toTarget) > 1e-4 else { return 0 }

        let f = simd_normalize(forward)
        let r = simd_normalize(right)
        let t = simd_normalize(toTarget)
        return Double(atan2(simd_dot(t, r), simd_dot(t, f)))
    }
}
