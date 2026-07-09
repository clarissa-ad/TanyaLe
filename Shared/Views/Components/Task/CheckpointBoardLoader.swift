//
//  CheckpointBoardLoader.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 07/07/26.
//

import RealityKit
import UIKit

/// Drops checkpoints into a shared AR scene: a green marker box for every
/// checkpoint, plus an interactive MCQ / emoji-slider board that faces the
/// camera for survey checkpoints, or a floating title label otherwise.
///
/// Shared by every AR screen that renders the same survey world (e.g.
/// `RelativeUserARView`, `ARWalkView`) so the board-building logic lives in
/// exactly one place instead of being copy-pasted per screen.
enum CheckpointBoardLoader {
    /// - Parameters:
    ///   - arContainer: the scene to add anchors to and register camera-facing
    ///     entities / interactive boards with.
    ///   - checkpoints: the checkpoints to render.
    ///   - onEmojiCelebration: called with the chosen emoji when an emoji-slider
    ///     board is submitted, so the host view can play its celebration.
    @MainActor
    static func load(
        into arContainer: RelativeUserARView.ARContainer,
        checkpoints: [Checkpoint],
        onEmojiCelebration: @escaping (String) -> Void
    ) {
        guard let arView = arContainer.view else { return }

        for cp in checkpoints {
            let position = SIMD3<Float>(cp.relativeX, cp.relativeY, cp.relativeZ)
            let anchor = AnchorEntity(world: position)
            arView.scene.addAnchor(anchor)

            let isSurvey = cp.hasMCQ || cp.hasEmojiSlider

            // Load the Lele checkpoint model as the marker. Loading a .usdz is
            // async, so we build it in a Task and fall back to a green box if it
            // can't be found. The floating title label (non-survey checkpoints)
            // is attached to whichever marker ends up being used.
            Task { @MainActor in
                let marker: Entity
                if let model = try? await Entity(named: "Lele_Checkpoint") {
                    marker = model
                    // The .usdz is authored ~2.4 m tall with its origin at the
                    // body centre; RealityKit treats 1 unit = 1 m, so scale it
                    // down and drop it onto the anchor instead of swallowing it.
                    normalizeMarker(marker)
                } else {
                    let boxMesh = MeshResource.generateBox(size: 0.2)
                    let material = SimpleMaterial(color: .green, isMetallic: true)
                    marker = ModelEntity(mesh: boxMesh, materials: [material])
                }
                anchor.addChild(marker)

                if !isSurvey {
                    // No survey configured yet: show a floating title label instead.
                    let textMesh = MeshResource.generateText(
                        cp.title,
                        extrusionDepth: 0.01,
                        font: .systemFont(ofSize: 0.1),
                        containerFrame: .zero,
                        alignment: .center,
                        lineBreakMode: .byWordWrapping
                    )
                    let textEntity = ModelEntity(mesh: textMesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
                    // Center the text on its holder so the camera-facing rotation
                    // pivots around the middle instead of the glyphs' corner.
                    textEntity.position = [-textMesh.bounds.center.x, 0, 0]

                    let titleHolder = Entity()
                    titleHolder.position = [0, 0.25, 0]
                    titleHolder.addChild(textEntity)
                    marker.addChild(titleHolder)
                    arContainer.faceCameraEntities.append(titleHolder)
                }
            }

            if isSurvey {
                // Interactive survey card floats above the marker. It gets
                // yawed toward the camera every frame, staying upright like a
                // beacon, and answers are given by tapping the card itself.
                Task { @MainActor in
                    let saveAnswer: (String) -> Void = { answer in
                        MockDatabaseService.shared.saveResponse(checkpointID: cp.id, answer: answer)
                    }
                    let controller: (any ARSurveyBoard)?
                    if cp.hasMCQ {
                        controller = await MCQBoardController.make(for: cp, onSubmit: saveAnswer)
                    } else {
                        controller = await EmojiSliderBoardController.make(for: cp) { answer, chosenEmoji in
                            saveAnswer(answer)
                            onEmojiCelebration(chosenEmoji)
                        }
                    }

                    if let controller {
                        controller.rootEntity.position = [0, 1.0, 0]
                        anchor.addChild(controller.rootEntity)
                        arContainer.faceCameraEntities.append(controller.rootEntity)
                        arContainer.boardControllers.append(controller)
                    }
                }
            }
        }
    }

    /// Scales a freshly-loaded marker entity to a sensible AR size and lifts it
    /// so its base rests on the anchor point. `.usdz` models are frequently
    /// authored several metres tall with their origin at the centre; since
    /// RealityKit maps 1 unit to 1 metre, dropping one in unmodified makes it
    /// engulf the camera. Measuring the model's real bounds at runtime keeps
    /// this correct even if the asset's authored size changes later.
    @MainActor
    static func normalizeMarker(_ marker: Entity, targetHeight: Float = 0.4) {
        let bounds = marker.visualBounds(relativeTo: marker)
        let height = bounds.extents.y
        guard height > 0 else { return }
        let scale = targetHeight / height
        marker.scale = SIMD3<Float>(repeating: scale)
        // After scaling, shift up so the lowest point sits at the anchor (y = 0).
        marker.position.y = -bounds.min.y * scale
    }
}
