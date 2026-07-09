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

            arContainer.checkpointAnchors[cp.id] = anchor
            arView.scene.addAnchor(anchor)
            
            // ── Load 3D Gallery Photos ──
            if cp.interactionType == .photobooth {
                let allPhotos = MockPhotoService.shared.fetchPhotos(forCheckpoint: cp.id)
                
                // You can adjust the max amount of image previews here:
                let maxPreviews = 5
                let photos = Array(allPhotos.prefix(maxPreviews))
                
                for (index, image) in photos.enumerated() {
                    Task { @MainActor in
                        if let entity = createPhotoEntity(from: image) {
                            // Float slightly above and spread horizontally with wider spacing
                            let spacing: Float = 0.5 // Adjust this to give more/less space
                            let offset = Float(index) * spacing - Float(max(0, photos.count - 1)) * (spacing / 2)
                            entity.position = [offset, 0.3 + Float(index % 2) * 0.05, 0]
                            anchor.addChild(entity)
                            arContainer.faceCameraEntities.append(entity)
                        }
                    }
                }
            }
        }
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
    
    /// Bakes the UIImage's orientation into its pixel data so RealityKit doesn't render it sideways
    private static func normalizeOrientation(of image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return normalized
    }
}
