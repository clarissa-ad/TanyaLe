//
//  PhotoboothBoardController.swift
//  TanyaLe
//
//  Created by AI Assistant.
//

import SwiftUI
import RealityKit

@MainActor
final class PhotoboothBoardController: ARSurveyBoard {
    let rootEntity = Entity()
    
    private let checkpoint: Checkpoint
    private let onTapCamera: () -> Void
    private let onTapGallery: () -> Void
    
    private var cameraHitEntity: Entity?
    private var galleryHitEntity: Entity?
    
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
        
        guard let questionPiece = await SurveyCard.renderPiece(PromptTextView(text: questionText)) else { return false }
        
        var promptImagePiece: SurveyCard.RenderedPiece?
        if let pid = checkpoint.promptPhotoID, let img = MockPhotoService.shared.fetchPromptPhoto(id: pid) {
            promptImagePiece = await SurveyCard.renderPiece(PromptImageView(image: img))
        } else {
            promptImagePiece = await SurveyCard.renderPiece(PromptImageFallbackView())
        }
        guard let imagePiece = promptImagePiece else { return false }
        
        guard let buttonsPiece = await SurveyCard.renderPiece(ButtonsRowView()) else { return false }
        
        let s = SurveyCard.metersPerPoint
        
        // Calculate total height
        var contentHeight = questionPiece.sizePoints.height + SurveyCard.sectionSpacingPoints
        contentHeight += imagePiece.sizePoints.height + SurveyCard.sectionSpacingPoints
        contentHeight += buttonsPiece.sizePoints.height
        let cardHeight = contentHeight + SurveyCard.paddingPoints * 2
        
        // Background card
        let bgEntity = SurveyCard.backgroundEntity(cardHeightPoints: cardHeight)
        rootEntity.addChild(bgEntity)
        
        // Layout pieces vertically
        var cursor = Float(cardHeight) * s / 2 - Float(SurveyCard.paddingPoints) * s
        
        // 1. Question Text
        let qEntity = SurveyCard.pieceEntity(questionPiece)
        qEntity.position = [0, cursor - Float(questionPiece.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(qEntity)
        cursor -= Float(questionPiece.sizePoints.height + SurveyCard.sectionSpacingPoints) * s
        
        // 2. Image
        let imgEntity = SurveyCard.pieceEntity(imagePiece)
        imgEntity.position = [0, cursor - Float(imagePiece.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(imgEntity)
        cursor -= Float(imagePiece.sizePoints.height + SurveyCard.sectionSpacingPoints) * s
        
        // 3. Buttons
        let btnsEntity = SurveyCard.pieceEntity(buttonsPiece)
        btnsEntity.position = [0, cursor - Float(buttonsPiece.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(btnsEntity)
        
        // Split the collision into two boxes: top for camera (text + image), bottom for gallery
        let boardHeightMeters = Float(cardHeight) * s
        
        let mainHit = Entity()
        mainHit.components.set(CollisionComponent(shapes: [
            .generateBox(width: SurveyCard.boardWidthMeters,
                         height: boardHeightMeters * 0.75,
                         depth: 0.02)
        ]))
        mainHit.position.y = boardHeightMeters * 0.125
        rootEntity.addChild(mainHit)
        self.cameraHitEntity = mainHit
        
        let galleryHit = Entity()
        galleryHit.components.set(CollisionComponent(shapes: [
            .generateBox(width: SurveyCard.boardWidthMeters,
                         height: boardHeightMeters * 0.25,
                         depth: 0.02)
        ]))
        galleryHit.position.y = -boardHeightMeters * 0.375
        rootEntity.addChild(galleryHit)
        self.galleryHitEntity = galleryHit
        
        return true
    }
    
    func handleTap(on entity: Entity, at worldPosition: SIMD3<Float>?, cameraPosition: SIMD3<Float>) -> Bool {
        let boardPosition = rootEntity.position(relativeTo: nil)
        guard simd_distance(boardPosition, cameraPosition) <= SurveyCard.maxInteractionDistance else { return false }
        
        if entity === cameraHitEntity {
            onTapCamera()
            return true
        } else if entity === galleryHitEntity {
            onTapGallery()
            return true
        }
        return false
    }
    
    func beginDrag(on entity: Entity, cameraPosition: SIMD3<Float>) -> Bool { false }
    func updateDrag(rayOrigin: SIMD3<Float>, rayDirection: SIMD3<Float>) {}
    func endDrag() {}
}

private struct PromptTextView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.black)
            .multilineTextAlignment(.center)
            .frame(width: SurveyCard.innerWidthPoints)
    }
}

private struct PromptImageView: View {
    let image: UIImage
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: SurveyCard.innerWidthPoints, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct PromptImageFallbackView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("Snap a photo here")
                .font(.headline)
                .foregroundColor(.gray)
        }
        .frame(width: SurveyCard.innerWidthPoints, height: 120)
        .background(Color(white: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ButtonsRowView: View {
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "camera")
                Text("Snap Photo")
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.55, green: 0.27, blue: 0.96))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            HStack {
                Image(systemName: "photo.on.rectangle")
                Text("Gallery")
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(white: 0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .frame(width: SurveyCard.innerWidthPoints)
    }
}
