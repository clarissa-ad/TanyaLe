//
//  CheckpointBoardLoader.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 07/07/26.
//

import RealityKit
import UIKit

/// Drops checkpoints into a shared AR scene: an interactive MCQ /
/// emoji-slider board for survey checkpoints, the real placed `.usdz` for
/// Like/Dislike checkpoints, or a green marker box with a floating title
/// label for anything else (including a Like/Dislike checkpoint whose asset
/// has no real model yet).
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
    ///     or Like/Dislike board is submitted, so the host view can play its
    ///     celebration.
    ///   - onShowAssetDetail: called with an asset id when a citizen taps
    ///     "Read more" on a Like/Dislike card, so the host view can present
    ///     the read-only asset detail sheet.
    @MainActor
    static func load(
        into arContainer: RelativeUserARView.ARContainer,
        checkpoints: [Checkpoint],
        onEmojiCelebration: @escaping (String) -> Void,
        onShowAssetDetail: @escaping (String) -> Void
    ) {
        guard let arView = arContainer.view else { return }

        for cp in checkpoints {
            let position = SIMD3<Float>(cp.relativeX, cp.relativeY, cp.relativeZ)
            let anchor = AnchorEntity(world: position)

            // Every checkpoint type except a placeable Like/Dislike asset
            // gets this box as its ground marker — the real 3D asset marks
            // its own spot, so it doesn't need one too.
            func addMarkerBox() -> ModelEntity {
                let boxMesh = MeshResource.generateBox(size: 0.2)
                let material = SimpleMaterial(color: .green, isMetallic: true)
                let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
                anchor.addChild(boxEntity)
                return boxEntity
            }

            // Deliberately NOT `cp.hasLikeDislike` — that also requires a
            // non-empty question, which matters for a future answer/vote
            // UI but has nothing to do with whether the 3D object itself
            // can be shown. Matches the exact gate the maker's placement
            // flow uses (`RelativeMakerARView.saveCheckpoint`), so a
            // checkpoint that got a live preview there always renders here
            // too, question or no question.
            let placeableAssetId = cp.interactionType == .likedislike
                ? cp.selectedAssetId.flatMap { id in AssetPlacementConfig.config(forAssetId: id) != nil ? id : nil }
                : nil

            if cp.hasMCQ || cp.hasEmojiSlider {
                _ = addMarkerBox()
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
            } else if let assetId = placeableAssetId {
                // Same `Asset3DLoader` the maker's placement preview uses —
                // already scaled and ground-snapped — so the citizen sees
                // exactly what was confirmed, just with the rotation
                // already locked in instead of being drag-adjustable.
                Task { @MainActor in
                    // Tracks the asset's height so the vote card (built
                    // below, once loading finishes either way) floats
                    // above it instead of guessing a fixed offset.
                    var assetHeightMeters: Float = 1.0
                    do {
                        let entity = try await Asset3DLoader.load(assetId: assetId)
                        anchor.addChild(entity)
                        entity.transform.rotation = simd_quatf(angle: cp.assetRotationY, axis: [0, 1, 0])
                        assetHeightMeters = entity.visualBounds(relativeTo: anchor).extents.y
                    } catch {
                        print("CheckpointBoardLoader: failed to load asset '\(assetId)' for checkpoint \(cp.id): \(error)")
                    }

                    // The card only needs a question to be meaningful — a
                    // Like/Dislike checkpoint whose question isn't filled in
                    // yet still shows the asset above, just without a card.
                    guard cp.hasLikeDislike else { return }
                    let assetDescription = MockAssetService.shared.asset(withId: assetId)?.description ?? ""

                    let controller = await LikeDislikeBoardController.make(
                        for: cp,
                        assetDescription: assetDescription,
                        onVote: { isLike in
                            MockDatabaseService.shared.recordVote(checkpointID: cp.id, isLike: isLike)
                            onEmojiCelebration(isLike ? "👍" : "👎")
                        },
                        onReadMore: {
                            onShowAssetDetail(assetId)
                        }
                    )

                    if let controller {
                        controller.rootEntity.position = [0, assetHeightMeters + 0.3, 0]
                        anchor.addChild(controller.rootEntity)
                        arContainer.faceCameraEntities.append(controller.rootEntity)
                        arContainer.boardControllers.append(controller)
                    }
                }
            } else {
                let boxEntity = addMarkerBox()
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
