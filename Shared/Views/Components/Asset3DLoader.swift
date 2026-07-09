import RealityKit
import Foundation

/// Loads a placeable 3D model for an asset, driven entirely by
/// `AssetPlacementConfig` — nothing outside this file needs to know a
/// `.usdz` filename or scale factor.
///
/// Baca dari AssetPlacementConfig, ambil file .usdz-nya dari folder project, "masak" jadi objek 3D yang siap pakai (udah di-scale sesuai config).
enum Asset3DLoader {
    enum LoadError: Error {
        /// The asset has no `AssetPlacementConfig` entry yet (no real
        /// `.usdz` shipped for it — still a gallery-only placeholder).
        case notPlaceable(assetId: String)
        /// The configured filename isn't actually bundled with the app.
        case resourceNotFound(fileName: String)
    }

    /// Loads the asset's model, scaled per its config, and returns it
    /// ground-snapped and wrapped in a plain pivot entity. Rotate the
    /// *returned* entity, not the model directly — some `.usdz` files carry
    /// internal transform/instancing quirks (e.g. geometry authored far off
    /// their own local origin, or instanced sub-parts) that make rotating
    /// their own root unreliable. A pivot we create ourselves has none of
    /// that baggage, so rotation always behaves the same regardless of how
    /// a given model was authored.
    @MainActor
    static func load(assetId: String) async throws -> Entity {
        guard let config = AssetPlacementConfig.config(forAssetId: assetId) else {
            throw LoadError.notPlaceable(assetId: assetId)
        }
        guard let url = Bundle.main.url(forResource: config.usdzFileName, withExtension: "usdz") else {
            throw LoadError.resourceNotFound(fileName: config.usdzFileName)
        }

        let model = try await Entity(contentsOf: url)
        // Multiply rather than overwrite: some `.usdz` files import with a
        // non-1.0 native scale already baked in (RealityKit applying the
        // file's own unit metadata, e.g. centimeters). Overwriting would
        // silently discard that correction; `config.scale` is meant as an
        // adjustment on top of however RealityKit already sized the model.
        model.scale *= SIMD3<Float>(repeating: config.scale)

        let pivot = Entity()
        pivot.addChild(model)
        model.snapBaseToParentOrigin()

        return pivot
    }
}
