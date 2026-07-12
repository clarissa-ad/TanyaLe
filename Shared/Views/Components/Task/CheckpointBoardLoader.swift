//
//  CheckpointBoardLoader.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 07/07/26.
//

import RealityKit
import UIKit

/// Minimal AR-scene surface that `CheckpointBoardLoader` needs, so the same
/// board-building logic can run from any host — the citizen walk views and
/// the maker's placement view — instead of being tied to one screen's
/// concrete container. Both `RelativeUserARView.ARContainer` and the maker
/// `ARContainer` conform.
protocol BoardHostContainer: AnyObject {
    var view: ARView? { get }
    /// Entities yawed toward the camera every frame (boards, labels).
    var faceCameraEntities: [Entity] { get set }
    /// Interactive survey cards, so taps/drags can be routed to them.
    var boardControllers: [any ARSurveyBoard] { get set }
    /// One anchor per rendered checkpoint, keyed by id — so a host can find
    /// and remove a checkpoint's scene content (e.g. to re-render after an
    /// edit) or attach to it later (e.g. photobooth photos).
    var checkpointAnchors: [UUID: AnchorEntity] { get set }
}

/// Drops checkpoints into a shared AR scene: an interactive MCQ /
/// emoji-slider board for survey checkpoints, the real placed `.usdz` for
/// Like/Dislike checkpoints, or the Lele checkpoint marker (green box
/// fallback) with a floating title label for anything else.
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
        into arContainer: any BoardHostContainer,
        checkpoints: [Checkpoint],
        onEmojiCelebration: @escaping (String) -> Void,
        onShowAssetDetail: @escaping (String) -> Void = { _ in },
        onPhotoboothTap: @escaping (Checkpoint) -> Void,
        onGalleryTap: @escaping (Checkpoint) -> Void,
        /// When false, board interactions don't write votes/answers to the
        /// store — used by the maker's preview so Pak RT trying out a board
        /// doesn't inflate real response counts.
        recordResponses: Bool = true,
        /// When false, survey boards' Submit button renders greyed out and
        /// can't be pressed — the maker preview shows the board read-only.
        submitEnabled: Bool = true
    ) {
        guard let arView = arContainer.view else { return }

        for cp in checkpoints {
            let position = SIMD3<Float>(cp.relativeX, cp.relativeY, cp.relativeZ)
            let anchor = AnchorEntity(world: position)
            arView.scene.addAnchor(anchor)
            // Track the anchor so the host can remove/rebuild this checkpoint
            // later (e.g. the maker re-rendering after an asset edit).
            arContainer.checkpointAnchors[cp.id] = anchor

            let isSurvey = cp.hasMCQ || cp.hasEmojiSlider || cp.interactionType == .photobooth

            // Deliberately NOT `cp.hasLikeDislike` — that also requires a
            // non-empty question, which matters for the vote UI but has
            // nothing to do with whether the 3D object itself can be shown.
            // Matches the exact gate the maker's placement flow uses
            // (`RelativeMakerARView.saveCheckpoint`), so a checkpoint that got
            // a live preview there always renders here too, question or not.
            let placeableAssetId = cp.interactionType == .likedislike
                ? cp.selectedAssetId.flatMap { id in AssetPlacementConfig.config(forAssetId: id) != nil ? id : nil }
                : nil

            if let assetId = placeableAssetId {
                // Like/Dislike renders the real placed asset (no Lele/box
                // marker — the asset marks its own spot) with an interactive
                // vote card floating above it. Same `Asset3DLoader` the
                // maker's placement preview uses — already scaled and
                // ground-snapped — so the citizen sees exactly what was
                // confirmed, just with the rotation already locked in.
                Task { @MainActor in
                    // Tracks the asset's height so the vote card floats above
                    // it instead of guessing a fixed offset.
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
                            if recordResponses {
                                MockDatabaseService.shared.recordVote(checkpointID: cp.id, isLike: isLike)
                            }
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
                continue
            }

            // Load the Lele checkpoint model as the marker. Loading a .usdz is
            // async, so we build it in a Task and fall back to a green box if it
            // can't be found. The floating title label (non-survey checkpoints)
            // is attached to whichever marker ends up being used.
            Task { @MainActor in
                let marker: Entity
                // Load lewat URL file eksplisit — `Entity(named:)` tidak andal
                // me-resolve .usdz ini dan diam-diam jatuh ke box hijau.
                if let url = Bundle.main.url(forResource: "Lele_Checkpoint", withExtension: "usdz"),
                   let model = try? await Entity(contentsOf: url) {
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
                        if recordResponses {
                            MockDatabaseService.shared.saveResponse(checkpointID: cp.id, answer: answer)
                        }
                    }
                    let controller: (any ARSurveyBoard)?
                    if cp.hasMCQ {
                        controller = await MCQBoardController.make(for: cp, submitEnabled: submitEnabled, onSubmit: saveAnswer)
                    } else if cp.interactionType == .photobooth {
                        controller = await PhotoboothBoardController.make(for: cp, onTapCamera: {
                            onPhotoboothTap(cp)
                        }, onTapGallery: {
                            onGalleryTap(cp)
                        })
                    } else {
                        controller = await EmojiSliderBoardController.make(for: cp, submitEnabled: submitEnabled) { answer, chosenEmoji in
                            saveAnswer(answer)
                            onEmojiCelebration(chosenEmoji)
                        }
                    }

                    if let controller {
                        if cp.interactionType == .photobooth {
                            // Raise the photobooth board to Y=1.0 (same as MCQ) so it clears Lele's collision bounds!
                            controller.rootEntity.position = [0, 1.0, 0]
                        } else {
                            controller.rootEntity.position = [0, 1.0, 0]
                        }
                        anchor.addChild(controller.rootEntity)
                        arContainer.faceCameraEntities.append(controller.rootEntity)
                        arContainer.boardControllers.append(controller)
                    } else {
                        print("CheckpointBoardLoader: board for '\(cp.title)' failed to build — renderPiece/texture returned nil")
                    }
                }
            }
            
            // ── Load 3D Gallery Photos ──
            if cp.interactionType == .photobooth {
                refreshPhotos(for: cp, in: arContainer)
            }
        }
    }

    /// Removes every checkpoint this loader added to the scene and resets the
    /// container's board tracking, so the host can re-render from scratch
    /// (e.g. the maker after editing a checkpoint's asset). Safe to call on a
    /// host whose only scene content is checkpoints — the reticle and other
    /// non-checkpoint entities aren't tracked here, so they're left alone.
    @MainActor
    static func clear(from arContainer: any BoardHostContainer) {
        for anchor in arContainer.checkpointAnchors.values {
            anchor.removeFromParent()
        }
        arContainer.checkpointAnchors.removeAll()
        arContainer.faceCameraEntities.removeAll()
        arContainer.boardControllers.removeAll()
    }
    
    /// Clears and re-renders the floating 3D photos for a given checkpoint.
    /// Used when a citizen takes a new photo or deletes one from the gallery.
    @MainActor
    static func refreshPhotos(for cp: Checkpoint, in arContainer: any BoardHostContainer) {
        guard let anchor = arContainer.checkpointAnchors[cp.id] else { return }
        
        // Remove existing photos (identified by name)
        let existingPhotos = anchor.children.filter { $0.name == "photo_preview" }
        for photo in existingPhotos {
            photo.removeFromParent()
            arContainer.faceCameraEntities.removeAll(where: { $0 === photo })
        }
        
        let allPhotos = MockPhotoService.shared.fetchPhotos(forCheckpoint: cp.id)
        let maxPreviews = 5
        let photos = Array(allPhotos.prefix(maxPreviews))
        
        for (index, image) in photos.enumerated() {
            Task { @MainActor in
                if let entity = createPhotoEntity(from: image) {
                    entity.name = "photo_preview" // Tag it so we can find it to delete later
                    
                    let offsets: [SIMD3<Float>] = [
                        [ 0.45,  1.3, -0.05], // Top Right
                        [-0.40,  0.7,  0.05], // Bottom Left
                        [ 0.40,  0.9,  0.10], // Middle Right
                        [-0.45,  1.1, -0.10], // Middle Left
                        [ 0.35,  0.6, -0.02]  // Bottom Right
                    ]
                    let tilts: [Float] = [
                         0.10,  // slightly right
                        -0.05,  // slightly left
                        -0.10,  // slightly left
                         0.05,  // slightly right
                         0.15   // more right
                    ]
                    
                    let pos = index < offsets.count ? offsets[index] : [0, 1.0, 0]
                    let tilt = index < tilts.count ? tilts[index] : 0
                    
                    entity.position = pos
                    entity.orientation = simd_quatf(angle: tilt, axis: [0, 0, 1])
                    
                    anchor.addChild(entity)
                    arContainer.faceCameraEntities.append(entity)
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
    
    @MainActor
    static func createPhotoEntity(from image: UIImage) -> Entity? {
        // Fix orientation (so it doesn't appear rotated 90 degrees)
        let normalizedImage = normalizeOrientation(of: image)
        
        // Prepare materials
        var mat = UnlitMaterial()
        
        // Attempt to generate texture from image
        if let cgImage = normalizedImage.cgImage,
           let tex = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)) {
            mat.color = .init(tint: .white, texture: .init(tex))
        } else if let ciImage = normalizedImage.ciImage {
            // Fallback for CIImage backed UIImages
            let context = CIContext()
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
               let tex = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)) {
                mat.color = .init(tint: .white, texture: .init(tex))
            } else {
                mat.color = .init(tint: .blue) // Debug fallback
            }
        } else {
            mat.color = .init(tint: .red) // Debug fallback
        }
        
        let aspect = Float(normalizedImage.size.width / max(1, normalizedImage.size.height))
        let w: Float = aspect > 1 ? 0.4 : 0.4 * aspect
        let h: Float = aspect > 1 ? 0.4 / aspect : 0.4
        
        // A plane generated with width/height stands vertically facing +Z.
        // It perfectly works with our yaw-only billboard rotation.
        let mesh = MeshResource.generatePlane(width: w, height: h)
        let model = ModelEntity(mesh: mesh, materials: [mat])
        
        // Add a slight white border backing by placing a slightly larger plane behind it
        let borderMesh = MeshResource.generatePlane(width: w + 0.02, height: h + 0.02)
        let borderMat = UnlitMaterial(color: .white)
        let borderModel = ModelEntity(mesh: borderMesh, materials: [borderMat])
        borderModel.position = [0, 0, -0.001]
        
        let holder = Entity()
        holder.addChild(model)
        holder.addChild(borderModel)
        
        return holder
    }
    
    /// Bakes the UIImage's orientation into its pixel data so RealityKit doesn't render it sideways,
    /// and scales it down to a max dimension to prevent severe memory spikes/lag when generating AR textures.
    private static func normalizeOrientation(of image: UIImage, maxDimension: CGFloat = 800) -> UIImage {
        let size = image.size
        var targetSize = size
        
        if size.width > maxDimension || size.height > maxDimension {
            let ratio = max(size.width, size.height) / maxDimension
            targetSize = CGSize(width: size.width / ratio, height: size.height / ratio)
        }
        
        // If it's already the right orientation and small enough, return it.
        if image.imageOrientation == .up && size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Use scale = 1.0 so we don't accidentally multiply the size by the device screen scale
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return normalized
    }
}
