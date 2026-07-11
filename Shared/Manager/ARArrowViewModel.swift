//
//  ARArrowViewModel.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 11/07/26.
//

import Foundation
import RealityKit

/// Loads the 3D navigator arrow (`Arrow.usdz`) and attaches it to a camera
/// anchor so it floats just below and ahead of the user. Shared by
/// `RelativeUserARView` and `ARWalkView`.
///
/// After loading, `CitizenARViewModel.updateTracking()` owns the arrow: it
/// aims `arContainer.arrowEntity` at the nearest *unanswered* checkpoint and
/// hides it when there is nothing left to answer.
@MainActor
enum ARArrowLoader {
    static func attach(to arContainer: RelativeUserARView.ARContainer) {
        guard let arView = arContainer.view else { return }

        let cameraAnchor = AnchorEntity(.camera)
        arView.scene.addAnchor(cameraAnchor)

        // Loading a .usdz is async, so the arrow appears a moment after the
        // world builds.
        Task { @MainActor in
            guard let url = Bundle.main.url(forResource: "Arrow", withExtension: "usdz") else {
                print("ARArrowLoader: Arrow.usdz not found in bundle")
                return
            }
            do {
                let arrow = try await Entity(contentsOf: url)

                // Normalize the model to ~10 cm on its longest side no matter
                // how large the .usdz was authored — reads as the small
                // navigator arrow in the design (Figma node 66-73), not a
                // screen-filling monolith.
                let extents = arrow.visualBounds(relativeTo: nil).extents
                let longestSide = max(extents.x, max(extents.y, extents.z))
                if longestSide > 0 {
                    arrow.scale *= SIMD3<Float>(repeating: 0.1 / longestSide)
                }

                // The model is authored tip-up (+Y), but look(at:) aims the
                // wrapper's -Z at the target. Pitch the model ~65° forward so
                // the tip points ahead while the face stays tilted toward the
                // viewer — a full 90° lies flat and is seen edge-on, nearly
                // invisible.
                arrow.orientation = simd_quatf(angle: -.pi * 65 / 180, axis: [1, 0, 0]) * arrow.orientation

                // Wrap the model in a plain pivot we own — rotating the
                // wrapper (rather than the model's own root) keeps orientation
                // reliable regardless of how the .usdz was authored.
                let wrapper = Entity()
                wrapper.position = [0, -0.12, -0.3]
                wrapper.addChild(arrow)
                // Hidden until an unanswered checkpoint comes into range.
                wrapper.isEnabled = false
                cameraAnchor.addChild(wrapper)

                arContainer.arrowEntity = wrapper
            } catch {
                print("ARArrowLoader: failed to load Arrow.usdz: \(error)")
            }
        }
    }
}
