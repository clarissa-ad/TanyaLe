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

            let boxMesh = MeshResource.generateBox(size: 0.2)
            let material = SimpleMaterial(color: .green, isMetallic: true)
            let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
            anchor.addChild(boxEntity)

            if cp.hasMCQ || cp.hasEmojiSlider {
                // Interactive survey card floats above the marker box. It gets
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
            } else {
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
                boxEntity.addChild(titleHolder)
                arContainer.faceCameraEntities.append(titleHolder)
            }

            arView.scene.addAnchor(anchor)
        }
    }
}
