import Foundation

/// Physical placement metadata for a 3D asset — the numbers RealityKit needs
/// to load and size a model correctly in AR. Kept separate from `Asset3D`
/// (gallery/display metadata for the Pak RT picker UI) because these values
/// only matter once an asset is actually placed in the AR scene, and have
/// nothing to do with how it's presented in the picker.
///
/// This is the single place scale/filename numbers live — nowhere else in
/// the placement code should hardcode either.
///
/// cm nyimpen data: "kandang_ayam itu file-nya asset3d_kandang-ayam.usdz, harus dikecilin jadi 0.01x biar pas ukurannya". Gak ada logic, cuma daftar angka.

struct AssetPlacementConfig {
    /// The `.usdz` filename in `Shared/Resources/Models3D/`, without the
    /// extension. Not derived from `Asset3D.id` — model filenames don't
    /// reliably follow the id's naming (e.g. "tempat_sampah" ships as
    /// "asset3d_trashbin.usdz").
    let usdzFileName: String

    /// Multiplier applied to the model's authored size so it reads as
    /// real-world scale in AR. 1.0 means "use the model as exported."
    /// Tune per-asset after eyeballing it in AR — there's no way to derive
    /// this automatically from the file.
    let scale: Float

    /// Y-axis rotation (radians) applied when the asset is first placed,
    /// before the user drags to adjust. Lets an asset default to facing a
    /// sensible direction instead of however it happened to be authored.
    let defaultRotationY: Float

    /// Assets that have a real `.usdz` and can be placed in AR. Assets not
    /// listed here (still SF Symbol placeholders in the gallery) simply
    /// aren't placeable yet — callers treat a missing entry as "not ready,"
    /// not as an error condition.
    private static let registry: [String: AssetPlacementConfig] = [
        // Authored in centimeters (raw extents ~303×184×318 at scale 1.0).
        // 0.01 is the real-world-accurate size (~3.0×1.8×3.2m), but that's
        // too large to test comfortably in a small indoor room — the
        // camera ends up standing inside the mesh, which reads as a
        // freeze/lag from the heavy overdraw of dense wire geometry filling
        // the whole screen. Scaled down temporarily to ~1.2×0.7×1.3m while
        // testing indoors; bump back toward 0.01 for outdoor/real-size use.
        "kandang_ayam": AssetPlacementConfig(
            usdzFileName: "asset3d_kandang-ayam",
            scale: 0.0004,
            defaultRotationY: 0
        ),
        // Authored in meters but modeled oversized (raw extents ~2.0×3.0×2.0
        // at scale 1.0 — a 3m-tall bin). 0.2 brings it down to a plausible
        // ~0.4×0.6×0.4m trash bin.
        "tempat_sampah": AssetPlacementConfig(
            usdzFileName: "asset3d_trashbin",
            scale: 0.2,
            defaultRotationY: 0
        )
    ]

    static func config(forAssetId id: String) -> AssetPlacementConfig? {
        registry[id]
    }
}
