//
//  PhotoboothBoardController.swift
//  TanyaLe
//
//  Created by AI Assistant.
//

import SwiftUI
import RealityKit

private let tanyaPurple = Color(red: 0.55, green: 0.27, blue: 0.96)

@MainActor
final class PhotoboothBoardController: ARSurveyBoard {
    let rootEntity = Entity()
    
    private let checkpoint: Checkpoint
    private let onTapCamera: () -> Void
    private let onTapGallery: () -> Void
    
    /// The tappable button row entity — stored so handleTap can match it.
    private var buttonsEntity: ModelEntity?
    
    private init(checkpoint: Checkpoint, onTapCamera: @escaping () -> Void, onTapGallery: @escaping () -> Void) {
        self.checkpoint = checkpoint
        self.onTapCamera = onTapCamera
        self.onTapGallery = onTapGallery
    }
    
    static func make(for checkpoint: Checkpoint, onTapCamera: @escaping () -> Void, onTapGallery: @escaping () -> Void) async -> PhotoboothBoardController? {
        let controller = PhotoboothBoardController(checkpoint: checkpoint, onTapCamera: onTapCamera, onTapGallery: onTapGallery)
        guard await controller.buildBoard() else { return nil }
        return controller
    }
    
    private func buildBoard() async -> Bool {
        let questionText = checkpoint.question.isEmpty ? checkpoint.taskDescription : checkpoint.question
        
        // CRITICAL: All sub-views must have .background(Color.white) to prevent
        // the transparent-→-black GPU texture rendering glitch in ImageRenderer.
        guard let questionPiece = await SurveyCard.renderPiece(PromptTextView(text: questionText)) else { return false }
        
        var promptImagePiece: SurveyCard.RenderedPiece?
        if let pid = checkpoint.promptPhotoID, let img = MockPhotoService.shared.fetchPromptPhoto(id: pid) {
            promptImagePiece = await SurveyCard.renderPiece(PromptImageView(image: img))
        }
        
        guard let buttonsPiece = await SurveyCard.renderPiece(ButtonsRowView()) else { return false }
        
        let s = SurveyCard.metersPerPoint
        
        // Calculate total card height
        var contentHeight = questionPiece.sizePoints.height + SurveyCard.sectionSpacingPoints
        if let ip = promptImagePiece {
            contentHeight += ip.sizePoints.height + SurveyCard.sectionSpacingPoints
        }
        contentHeight += buttonsPiece.sizePoints.height
        let cardHeight = contentHeight + SurveyCard.paddingPoints * 2
        
        // Background card — added directly to rootEntity (same pattern as MCQ)
        let bgEntity = SurveyCard.backgroundEntity(cardHeightPoints: cardHeight)
        rootEntity.addChild(bgEntity)
        
        // Stack pieces downward from the top, slightly in front of the background.
        var cursor = Float(cardHeight) * s / 2 - Float(SurveyCard.paddingPoints) * s
        
        // 1. Question Text
        let qEntity = SurveyCard.pieceEntity(questionPiece)
        qEntity.position = [0, cursor - Float(questionPiece.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(qEntity)
        cursor -= Float(questionPiece.sizePoints.height + SurveyCard.sectionSpacingPoints) * s
        
        // 2. Prompt image (if present)
        if let ip = promptImagePiece {
            let imgEntity = SurveyCard.pieceEntity(ip)
            imgEntity.position = [0, cursor - Float(ip.sizePoints.height) * s / 2, 0.002]
            rootEntity.addChild(imgEntity)
            cursor -= Float(ip.sizePoints.height + SurveyCard.sectionSpacingPoints) * s
        }
        
        // 3. Button row — tappable: true adds a CollisionComponent so hitTest picks it up.
        let btnsEntity = SurveyCard.pieceEntity(buttonsPiece, tappable: true)
        btnsEntity.position = [0, cursor - Float(buttonsPiece.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(btnsEntity)
        self.buttonsEntity = btnsEntity
        
        return true
    }
    
    func handleTap(on entity: Entity, at worldPosition: SIMD3<Float>?, cameraPosition: SIMD3<Float>) -> Bool {
        let boardPosition = rootEntity.position(relativeTo: nil)
        guard simd_distance(boardPosition, cameraPosition) <= SurveyCard.maxInteractionDistance else { return false }
        
        // Walk up the parent chain — RealityKit hitTest can return a child
        // sub-mesh of the ModelEntity, not the top-level entity we stored.
        var candidate: Entity? = entity
        while let e = candidate {
            if e === buttonsEntity, let worldPos = worldPosition {
                // Convert world tap position into the button entity's local space
                // to determine which button (left = Camera, right = Gallery) was hit.
                let localPos = buttonsEntity!.convert(position: worldPos, from: nil)
                if localPos.x < 0 {
                    onTapCamera()
                } else {
                    onTapGallery()
                }
                return true
            }
            candidate = e.parent
        }
        return false
    }
    
    func beginDrag(on entity: Entity, cameraPosition: SIMD3<Float>) -> Bool { false }
    func updateDrag(rayOrigin: SIMD3<Float>, rayDirection: SIMD3<Float>) {}
    func endDrag() {}
}

// MARK: - Sub-views
// CRITICAL: Every view needs .background(Color.white) to prevent the black
// texture glitch that occurs when ImageRenderer renders on a transparent layer.

private struct PromptTextView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: SurveyCard.innerWidthPoints)
            .padding(.vertical, 4)
            .background(Color.white) // ← MUST have white bg or text renders black
    }
}

private struct PromptImageView: View {
    let image: UIImage
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: SurveyCard.innerWidthPoints, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background(Color.white)
    }
}

private struct ButtonsRowView: View {
    var body: some View {
        HStack(spacing: 10) {
            // Snap Photo — left half (x < 0 in local space)
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                Text("Snap Photo")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(tanyaPurple)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            // Gallery — right half (x >= 0 in local space)
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                Text("Gallery")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color(white: 0.92))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .frame(width: SurveyCard.innerWidthPoints)
        .padding(4)
        .background(Color.white) // ← required to prevent black glitch
    }
}
