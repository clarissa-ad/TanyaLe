import RealityKit
import CoreGraphics

/// Owns the entity being interactively placed in AR for a Like/Dislike
/// checkpoint, plus the turntable-style rotation the user applies by
/// dragging. One controller exists per placement session — there is never
/// more than one asset being placed at a time, so unlike `ARSurveyBoard`
/// (which routes gestures across several simultaneous interactive boards
/// via hit-testing), this needs none: the Coordinator just forwards drag
/// deltas to whichever controller is currently active.
@MainActor
final class AssetPlacementController {
    /// The entity in the scene — already anchored, scaled, and ground-snapped.
    let rootEntity: Entity

    /// Current Y-axis rotation in radians, updated live as the user drags.
    private(set) var rotationY: Float

    private init(rootEntity: Entity, initialRotationY: Float) {
        self.rootEntity = rootEntity
        self.rotationY = initialRotationY
    }

    /// Loads the asset (already ground-snapped by `Asset3DLoader`), adds it
    /// to `anchor`, and returns a controller ready to receive rotation
    /// updates. `anchor` must already be positioned on the floor (e.g. from
    /// an ARKit plane raycast).
    static func make(assetId: String, anchor: AnchorEntity) async throws -> AssetPlacementController {
        let entity = try await Asset3DLoader.load(assetId: assetId)
        anchor.addChild(entity)

        let initialRotationY = AssetPlacementConfig.config(forAssetId: assetId)?.defaultRotationY ?? 0
        let controller = AssetPlacementController(rootEntity: entity, initialRotationY: initialRotationY)
        controller.applyRotation()
        return controller
    }

    /// Applies a horizontal screen-drag delta as a turntable rotation
    /// around the world Y axis — the same gesture as spinning a product
    /// preview. Dragging right spins the asset the same way regardless of
    /// which way the camera is currently facing, since rotation is applied
    /// directly in the entity's own local space.
    func rotate(byScreenDeltaX deltaX: CGFloat) {
        let sensitivity: Float = 0.01 // radians per point dragged
        rotationY += Float(deltaX) * sensitivity
        applyRotation()
    }

    /// Nudges the facing left/right by a fixed step — the arrow buttons'
    /// alternative to free dragging. Positive degrees turns the same way as
    /// dragging right. Mixable with `rotate(byScreenDeltaX:)` since both
    /// just update the same `rotationY` and re-apply it.
    func nudgeRotation(byDegrees degrees: Float) {
        rotationY += degrees * .pi / 180
        applyRotation()
    }

    private func applyRotation() {
        rootEntity.transform.rotation = simd_quatf(angle: rotationY, axis: [0, 1, 0])
    }

    /// Removes the entity from the scene — called when placement is
    /// cancelled instead of confirmed.
    func removeFromScene() {
        rootEntity.removeFromParent()
    }
}
