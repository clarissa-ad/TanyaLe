import SwiftUI
import RealityKit
import UIKit

/// The TanyaLe accent color used on the AR survey card.
private let tanyaPurple = Color(red: 0.55, green: 0.27, blue: 0.96)

/// Builds and drives the interactive floating AR survey card at an MCQ
/// checkpoint: white rounded card, radio-style options, and a submit pill,
/// matching the design mockup.
///
/// Every piece (question, each option row, submit button) is a SwiftUI view
/// rendered to a texture on its own plane with a collision shape, so taps on
/// the ARView can be routed to the exact option via `handleTap`. Selecting
/// swaps the row texture to its purple-checked state; submitting reports the
/// answer and replaces the card with a thank-you confirmation.
///
/// The root entity is meant to be rotated toward the camera every frame with
/// `yawToFace(cameraPosition:)`. Yaw-only rotation (around the world Y axis)
/// is used instead of `BillboardComponent` on purpose: a full billboard
/// pitches and rolls with the camera, making the card lie flat on the ground
/// when viewed from above. Yaw-only keeps it floating upright.
@MainActor
final class MCQBoardController {
    
    // Layout constants in points, mirroring the SwiftUI card design.
    private static let cardWidthPoints: CGFloat = 340
    private static let innerWidthPoints: CGFloat = 292
    private static let paddingPoints: CGFloat = 24
    private static let sectionSpacingPoints: CGFloat = 20
    private static let optionSpacingPoints: CGFloat = 12
    private static let cornerRadiusPoints: CGFloat = 24
    
    /// Card width in the AR world, in meters.
    private static let boardWidthMeters: Float = 0.5
    private static var metersPerPoint: Float { boardWidthMeters / Float(cardWidthPoints) }
    
    /// Citizens must be roughly this close (meters) for taps to register,
    /// keeping responses on-site (proximity gating).
    private static let maxInteractionDistance: Float = 3.0
    
    /// The entity to place in the scene (and yaw toward the camera).
    let rootEntity = Entity()
    
    private let checkpoint: Checkpoint
    private let onSubmit: (String) -> Void
    private var optionEntities: [ModelEntity] = []
    private var optionMaterials: [(normal: UnlitMaterial, selected: UnlitMaterial)] = []
    private var submitEntity: ModelEntity?
    private var selectedIndex: Int?
    private var isSubmitted = false
    
    private init(checkpoint: Checkpoint, onSubmit: @escaping (String) -> Void) {
        self.checkpoint = checkpoint
        self.onSubmit = onSubmit
    }
    
    /// Creates the interactive card for a checkpoint, or nil when it has no
    /// MCQ data. Async because texture uploads to the GPU are async.
    static func make(for checkpoint: Checkpoint, onSubmit: @escaping (String) -> Void) async -> MCQBoardController? {
        guard checkpoint.hasMCQ else { return nil }
        let controller = MCQBoardController(checkpoint: checkpoint, onSubmit: onSubmit)
        guard await controller.buildQuestionCard() else { return nil }
        return controller
    }
    
    /// Routes a tapped entity to the matching option or the submit button.
    /// Returns true when the tap belonged to this board.
    func handleTap(on tappedEntity: Entity, cameraPosition: SIMD3<Float>) -> Bool {
        guard !isSubmitted else { return false }
        
        // Proximity gate: ignore taps from too far away.
        let boardPosition = rootEntity.position(relativeTo: nil)
        guard simd_distance(boardPosition, cameraPosition) <= Self.maxInteractionDistance else { return false }
        
        if let index = optionEntities.firstIndex(where: { $0 === tappedEntity }) {
            select(index)
            return true
        }
        if tappedEntity === submitEntity {
            submit()
            return true
        }
        return false
    }
    
    // MARK: - Interaction
    
    private func select(_ index: Int) {
        selectedIndex = index
        for (i, entity) in optionEntities.enumerated() {
            entity.model?.materials = [i == index ? optionMaterials[i].selected : optionMaterials[i].normal]
        }
    }
    
    private func submit() {
        guard let selectedIndex, !isSubmitted else { return }
        isSubmitted = true
        onSubmit(checkpoint.surveyOptions[selectedIndex])
        Task { @MainActor in
            await self.showThankYouCard()
        }
    }
    
    // MARK: - Card construction
    
    private func buildQuestionCard() async -> Bool {
        let s = Self.metersPerPoint
        
        guard let question = await Self.renderPiece(QuestionTextView(text: checkpoint.question)) else { return false }
        
        var optionPieces: [(normal: RenderedPiece, selected: RenderedPiece)] = []
        for option in checkpoint.surveyOptions {
            guard let normal = await Self.renderPiece(OptionRowView(text: option, isSelected: false)),
                  let selected = await Self.renderPiece(OptionRowView(text: option, isSelected: true)) else { return false }
            optionPieces.append((normal, selected))
        }
        
        guard let submit = await Self.renderPiece(SubmitButtonView()) else { return false }
        
        // Total card height in points.
        var contentHeight = question.sizePoints.height + Self.sectionSpacingPoints
        contentHeight += optionPieces.reduce(0) { $0 + $1.normal.sizePoints.height }
        contentHeight += CGFloat(max(0, optionPieces.count - 1)) * Self.optionSpacingPoints
        contentHeight += Self.sectionSpacingPoints + submit.sizePoints.height
        let cardHeight = contentHeight + Self.paddingPoints * 2
        
        // White rounded card background.
        let backgroundMesh = MeshResource.generatePlane(
            width: Self.boardWidthMeters,
            height: Float(cardHeight) * s,
            cornerRadius: Float(Self.cornerRadiusPoints) * s
        )
        let background = ModelEntity(mesh: backgroundMesh, materials: [UnlitMaterial(color: .white)])
        rootEntity.addChild(background)
        
        // Stack the pieces downward from the top of the card, slightly in
        // front of the background so they render on top.
        var cursor = Float(cardHeight) * s / 2 - Float(Self.paddingPoints) * s
        
        let questionEntity = Self.pieceEntity(question)
        questionEntity.position = [0, cursor - Float(question.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(questionEntity)
        cursor -= Float(question.sizePoints.height + Self.sectionSpacingPoints) * s
        
        for pieces in optionPieces {
            let heightMeters = Float(pieces.normal.sizePoints.height) * s
            let rowEntity = Self.pieceEntity(pieces.normal, tappable: true)
            rowEntity.position = [0, cursor - heightMeters / 2, 0.002]
            rootEntity.addChild(rowEntity)
            optionEntities.append(rowEntity)
            optionMaterials.append((pieces.normal.material, pieces.selected.material))
            cursor -= heightMeters + Float(Self.optionSpacingPoints) * s
        }
        cursor -= Float(Self.sectionSpacingPoints - Self.optionSpacingPoints) * s
        
        let submitButton = Self.pieceEntity(submit, tappable: true)
        submitButton.position = [0, cursor - Float(submit.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(submitButton)
        submitEntity = submitButton
        
        return true
    }
    
    private func showThankYouCard() async {
        guard let piece = await Self.renderPiece(ThankYouCardView()) else { return }
        
        // Replace the question card with the confirmation card.
        for child in Array(rootEntity.children) {
            child.removeFromParent()
        }
        optionEntities = []
        optionMaterials = []
        submitEntity = nil
        
        let mesh = MeshResource.generatePlane(
            width: Float(piece.sizePoints.width) * Self.metersPerPoint,
            height: Float(piece.sizePoints.height) * Self.metersPerPoint,
            cornerRadius: Float(Self.cornerRadiusPoints) * Self.metersPerPoint
        )
        rootEntity.addChild(ModelEntity(mesh: mesh, materials: [piece.material]))
    }
    
    // MARK: - Rendering helpers
    
    /// A SwiftUI view rendered to a texture, with its layout size in points.
    private struct RenderedPiece {
        let texture: TextureResource
        let sizePoints: CGSize
        
        var material: UnlitMaterial {
            var material = UnlitMaterial()
            material.color = .init(texture: .init(texture))
            return material
        }
    }
    
    private static func renderPiece<Content: View>(_ content: Content) async -> RenderedPiece? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        guard let cgImage = renderer.cgImage else { return nil }
        guard let texture = try? await TextureResource(image: cgImage, options: .init(semantic: .color)) else { return nil }
        let size = CGSize(width: CGFloat(cgImage.width) / renderer.scale,
                          height: CGFloat(cgImage.height) / renderer.scale)
        return RenderedPiece(texture: texture, sizePoints: size)
    }
    
    private static func pieceEntity(_ piece: RenderedPiece, tappable: Bool = false) -> ModelEntity {
        let widthMeters = Float(piece.sizePoints.width) * metersPerPoint
        let heightMeters = Float(piece.sizePoints.height) * metersPerPoint
        let entity = ModelEntity(
            mesh: .generatePlane(width: widthMeters, height: heightMeters),
            materials: [piece.material]
        )
        if tappable {
            // Collision shape so ARView.entity(at:) can hit-test taps.
            entity.collision = CollisionComponent(shapes: [
                .generateBox(width: widthMeters, height: heightMeters, depth: 0.01)
            ])
        }
        return entity
    }
}

// MARK: - Card piece designs (rendered to textures)

private struct QuestionTextView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(.black)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 292, alignment: .leading)
            .background(Color.white)
    }
}

private struct OptionRowView: View {
    let text: String
    let isSelected: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(isSelected ? tanyaPurple : Color.gray.opacity(0.6))
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .frame(width: 292, alignment: .leading)
        .background(Color.white)
    }
}

private struct SubmitButtonView: View {
    var body: some View {
        Text("Submit")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(Capsule().fill(tanyaPurple))
            .padding(4)
            .background(Color.white)
    }
}

private struct ThankYouCardView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("🎉")
                .font(.system(size: 54))
            Text("Thank you for filling!")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
            Text("You can continue your journey to another checkpoint")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Text("Explore more")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Capsule().fill(tanyaPurple))
                .padding(.top, 8)
        }
        .padding(28)
        .frame(width: 340)
        .background(Color.white)
    }
}

extension Entity {
    /// Rotates the entity around the world Y axis so its front (+Z) points
    /// toward the camera, while staying upright relative to gravity. Call
    /// this every frame (e.g. from a `SceneEvents.Update` subscription) to
    /// keep AR content readable from any direction and any phone orientation.
    func yawToFace(cameraPosition: SIMD3<Float>) {
        let worldPosition = position(relativeTo: nil)
        let direction = cameraPosition - worldPosition
        // Ignore the degenerate case of the camera being directly above/below.
        guard abs(direction.x) > 0.0001 || abs(direction.z) > 0.0001 else { return }
        let yaw = atan2(direction.x, direction.z)
        setOrientation(simd_quatf(angle: yaw, axis: [0, 1, 0]), relativeTo: nil)
    }
}
