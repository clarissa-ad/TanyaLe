//
//  ARSurveyBoard.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 06/07/26.
//

import SwiftUI
import RealityKit
import UIKit

/// An interactive floating AR survey card that can receive taps.
///
/// The root entity is meant to be rotated toward the camera every frame with
/// `yawToFace(cameraPosition:)`. Yaw-only rotation (around the world Y axis)
/// is used instead of `BillboardComponent` on purpose: a full billboard
/// pitches and rolls with the camera, making the card lie flat on the ground
/// when viewed from above. Yaw-only keeps it floating upright.
@MainActor
protocol ARSurveyBoard: AnyObject {
    /// The entity to place in the scene (and yaw toward the camera).
    var rootEntity: Entity { get }

    /// Routes a tapped entity (and the tap's world-space position) to the
    /// board. Returns true when the tap belonged to this board.
    func handleTap(on entity: Entity, at worldPosition: SIMD3<Float>?, cameraPosition: SIMD3<Float>) -> Bool

    /// Offers the start of a drag gesture that landed on the given entity.
    /// Returns true when this board claims the drag (e.g. a slider grab).
    func beginDrag(on entity: Entity, cameraPosition: SIMD3<Float>) -> Bool

    /// Continues a claimed drag with the current finger ray from the camera.
    func updateDrag(rayOrigin: SIMD3<Float>, rayDirection: SIMD3<Float>)

    /// Finishes a claimed drag.
    func endDrag()
}

// Boards without draggable content ignore drags by default.
extension ARSurveyBoard {
    func beginDrag(on entity: Entity, cameraPosition: SIMD3<Float>) -> Bool { false }
    func updateDrag(rayOrigin: SIMD3<Float>, rayDirection: SIMD3<Float>) {}
    func endDrag() {}
}
