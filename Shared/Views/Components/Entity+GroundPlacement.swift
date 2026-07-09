import RealityKit

extension Entity {
    /// Shifts this entity along Y so the base of its bounding box sits
    /// exactly at its parent's origin, instead of wherever the model's
    /// authored pivot happens to be (often its center). Call this once,
    /// right after adding the entity as a child of the anchor that's
    /// already positioned on the floor (e.g. from an ARKit plane raycast)
    /// — every asset then sits flush on the ground, never floating, never
    /// sunk in, regardless of how its `.usdz` was originally modeled.
    ///
    /// Must be called after the entity has a `parent` and after any scale
    /// has been applied, since bounds are measured relative to the parent
    /// (which bakes in this entity's own scale) rather than in the
    /// entity's own local space (which would not).
    ///
    /// fungsi snapBaseToParentOrigin(). Tugasnya cek "alas objek 3D ini ada di ketinggian berapa?" terus geser objeknya dikit biar alasnya pas di lantai — gak ngambang, gak nyelem.
    func snapBaseToParentOrigin() {
        guard let parent else { return }
        let bounds = visualBounds(relativeTo: parent)
        guard !bounds.isEmpty else { return }
        position.y -= bounds.min.y
    }
}
