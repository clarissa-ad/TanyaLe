//
//  WalkableAspirationSceneController.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 05/07/26.
//

import Foundation
import RealityKit
import ARKit
import Combine
import CoreLocation

/// Owns the ARView and everything living in the AR scene for Walkable Aspirations.
/// Insulates the ARView from SwiftUI re-renders (same trick as RelativeUserARView)
/// and is the single place that mutates the RealityKit scene. It deliberately does
/// NOT persist anything — it hands the built `WalkableAspiration` back to the caller,
/// keeping `WalkableAspirationManager` free of any RealityKit/ARKit dependency.
final class WalkableAspirationSceneController {
    var view: ARView?
    // Message cards that should keep facing the camera (yaw-only).
    var faceCameraEntities: [Entity] = []
    var updateSubscription: Cancellable?
    // Board controllers kept alive while their cards are in the scene.
    var boardControllers: [any ARSurveyBoard] = []

    /// Drop a floating message board at the exact spot the user is standing and
    /// return the `WalkableAspiration` describing it, or `nil` if there's no valid
    /// message / AR frame. The caller is responsible for persisting the result.
    func dropMessageBoard(message: String, coordinate: CLLocationCoordinate2D?) -> WalkableAspiration? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let arView = view,
              let frame = arView.session.currentFrame else { return nil }

        // Camera transform = where the phone is. columns.3 is its world position.
        let cam = frame.camera.transform
        let camPos = SIMD3<Float>(cam.columns.3.x, cam.columns.3.y, cam.columns.3.z)

        // The user's feet are roughly 1.4m below the phone. Anchor at the ground
        // where they're standing; the card itself floats up from there.
        let standing = SIMD3<Float>(camPos.x, camPos.y - 1.4, camPos.z)

        // Build the message board and anchor it at the standing spot. Building the
        // card is async (texture upload), so it's added when ready.
        let anchor = AnchorEntity(world: standing)
        arView.scene.addAnchor(anchor)

        Task { @MainActor in
            guard let controller = await MessageBoardController.make(message: trimmed) else { return }
            // Float the card up to roughly chest height above where they stood,
            // and keep it turned toward the camera every frame.
            controller.rootEntity.position = [0, 1.2, 0]
            anchor.addChild(controller.rootEntity)
            self.faceCameraEntities.append(controller.rootEntity)
            self.boardControllers.append(controller)
        }

        return WalkableAspiration(
            message: trimmed,
            latitude: coordinate?.latitude ?? 0,
            longitude: coordinate?.longitude ?? 0,
            relativeX: standing.x,
            relativeY: standing.y,
            relativeZ: standing.z
        )
    }
}
