import SwiftUI
import RealityKit
import UIKit

/// The TanyaLe accent color used on the AR survey cards.
private let tanyaPurple = Color(red: 0.55, green: 0.27, blue: 0.96)

// MARK: - Shared card rendering

/// Shared layout constants and texture-rendering helpers for the AR survey
/// cards. Every card piece is a SwiftUI view rendered to a texture on its own
/// plane, so the cards look exactly like the design while staying lightweight
/// for the App Clip (no bundled assets).
@MainActor
enum SurveyCard {

    // Layout constants in points, mirroring the SwiftUI card designs.
    static let cardWidthPoints: CGFloat = 340
    static let innerWidthPoints: CGFloat = 292
    static let paddingPoints: CGFloat = 24
    static let sectionSpacingPoints: CGFloat = 20
    static let optionSpacingPoints: CGFloat = 12
    static let cornerRadiusPoints: CGFloat = 24

    /// Card width in the AR world, in meters.
    static let boardWidthMeters: Float = 0.5
    static var metersPerPoint: Float { boardWidthMeters / Float(cardWidthPoints) }

    /// Citizens must be roughly this close (meters) for taps to register,
    /// keeping responses on-site (proximity gating).
    static let maxInteractionDistance: Float = 3.0

    /// A SwiftUI view rendered to a texture, with its layout size in points.
    struct RenderedPiece {
        let texture: TextureResource
        let sizePoints: CGSize

        var material: UnlitMaterial {
            var material = UnlitMaterial()
            material.color = .init(texture: .init(texture))
            return material
        }
    }

    static func renderPiece<Content: View>(_ content: Content) async -> RenderedPiece? {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        guard let cgImage = renderer.cgImage else { return nil }
        guard let texture = try? await TextureResource(image: cgImage, options: .init(semantic: .color)) else { return nil }
        let size = CGSize(width: CGFloat(cgImage.width) / renderer.scale,
                          height: CGFloat(cgImage.height) / renderer.scale)
        return RenderedPiece(texture: texture, sizePoints: size)
    }

    static func pieceEntity(_ piece: RenderedPiece, tappable: Bool = false) -> ModelEntity {
        let widthMeters = Float(piece.sizePoints.width) * metersPerPoint
        let heightMeters = Float(piece.sizePoints.height) * metersPerPoint
        let entity = ModelEntity(
            mesh: .generatePlane(width: widthMeters, height: heightMeters),
            materials: [piece.material]
        )
        if tappable {
            // Collision shape so ARView taps can be hit-tested.
            entity.collision = CollisionComponent(shapes: [
                .generateBox(width: widthMeters, height: heightMeters, depth: 0.01)
            ])
        }
        return entity
    }

    /// The white rounded card background sized to the given content height.
    static func backgroundEntity(cardHeightPoints: CGFloat) -> ModelEntity {
        let mesh = MeshResource.generatePlane(
            width: boardWidthMeters,
            height: Float(cardHeightPoints) * metersPerPoint,
            cornerRadius: Float(cornerRadiusPoints) * metersPerPoint
        )
        return ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
    }

    /// Replaces the card's content with the thank-you confirmation card.
    static func swapToThankYouCard(on rootEntity: Entity) async {
        guard let piece = await renderPiece(ThankYouCardView()) else { return }

        for child in Array(rootEntity.children) {
            child.removeFromParent()
        }

        let mesh = MeshResource.generatePlane(
            width: Float(piece.sizePoints.width) * metersPerPoint,
            height: Float(piece.sizePoints.height) * metersPerPoint,
            cornerRadius: Float(cornerRadiusPoints) * metersPerPoint
        )
        rootEntity.addChild(ModelEntity(mesh: mesh, materials: [piece.material]))
    }
}

// MARK: - MCQ card

/// Builds and drives the interactive floating MCQ card: white rounded card,
/// radio-style options, and a submit pill. Selecting swaps the row texture to
/// its purple-checked state; submitting reports the answer and replaces the
/// card with the thank-you confirmation.
@MainActor
final class MCQBoardController: ARSurveyBoard {

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

    func handleTap(on tappedEntity: Entity, at worldPosition: SIMD3<Float>?, cameraPosition: SIMD3<Float>) -> Bool {
        guard !isSubmitted else { return false }

        // Proximity gate: ignore taps from too far away.
        let boardPosition = rootEntity.position(relativeTo: nil)
        guard simd_distance(boardPosition, cameraPosition) <= SurveyCard.maxInteractionDistance else { return false }

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
            await SurveyCard.swapToThankYouCard(on: self.rootEntity)
        }
    }

    private func buildQuestionCard() async -> Bool {
        let s = SurveyCard.metersPerPoint

        guard let question = await SurveyCard.renderPiece(QuestionTextView(text: checkpoint.question)) else { return false }

        var optionPieces: [(normal: SurveyCard.RenderedPiece, selected: SurveyCard.RenderedPiece)] = []
        for option in checkpoint.surveyOptions {
            guard let normal = await SurveyCard.renderPiece(OptionRowView(text: option, isSelected: false)),
                  let selected = await SurveyCard.renderPiece(OptionRowView(text: option, isSelected: true)) else { return false }
            optionPieces.append((normal, selected))
        }

        guard let submit = await SurveyCard.renderPiece(SubmitButtonView()) else { return false }

        // Total card height in points.
        var contentHeight = question.sizePoints.height + SurveyCard.sectionSpacingPoints
        contentHeight += optionPieces.reduce(0) { $0 + $1.normal.sizePoints.height }
        contentHeight += CGFloat(max(0, optionPieces.count - 1)) * SurveyCard.optionSpacingPoints
        contentHeight += SurveyCard.sectionSpacingPoints + submit.sizePoints.height
        let cardHeight = contentHeight + SurveyCard.paddingPoints * 2

        rootEntity.addChild(SurveyCard.backgroundEntity(cardHeightPoints: cardHeight))

        // Stack the pieces downward from the top of the card, slightly in
        // front of the background so they render on top.
        var cursor = Float(cardHeight) * s / 2 - Float(SurveyCard.paddingPoints) * s

        let questionEntity = SurveyCard.pieceEntity(question)
        questionEntity.position = [0, cursor - Float(question.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(questionEntity)
        cursor -= Float(question.sizePoints.height + SurveyCard.sectionSpacingPoints) * s

        for pieces in optionPieces {
            let heightMeters = Float(pieces.normal.sizePoints.height) * s
            let rowEntity = SurveyCard.pieceEntity(pieces.normal, tappable: true)
            rowEntity.position = [0, cursor - heightMeters / 2, 0.002]
            rootEntity.addChild(rowEntity)
            optionEntities.append(rowEntity)
            optionMaterials.append((pieces.normal.material, pieces.selected.material))
            cursor -= heightMeters + Float(SurveyCard.optionSpacingPoints) * s
        }
        cursor -= Float(SurveyCard.sectionSpacingPoints - SurveyCard.optionSpacingPoints) * s

        let submitButton = SurveyCard.pieceEntity(submit, tappable: true)
        submitButton.position = [0, cursor - Float(submit.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(submitButton)
        submitEntity = submitButton

        return true
    }
}

// MARK: - Emoji slider card

/// Builds and drives the interactive floating emoji slider card: a question
/// with a horizontal track between two emoji (configured by the maker) and a
/// purple knob. Tapping along the track positions the knob; submitting
/// reports the value as a percentage toward the right emoji and replaces the
/// card with the thank-you confirmation.
@MainActor
final class EmojiSliderBoardController: ARSurveyBoard {

    private static let trackHeightPoints: CGFloat = 6
    private static let sliderSpacingPoints: CGFloat = 10

    let rootEntity = Entity()

    private let checkpoint: Checkpoint
    private let onSubmit: (_ answer: String, _ chosenEmoji: String) -> Void
    private var trackEntity: ModelEntity?
    private var knobEntity: ModelEntity?
    private var submitEntity: ModelEntity?
    private var trackCenterXMeters: Float = 0
    private var trackWidthMeters: Float = 0
    private var value: Float?
    private var isSubmitted = false
    private var isDragging = false

    private init(checkpoint: Checkpoint, onSubmit: @escaping (_ answer: String, _ chosenEmoji: String) -> Void) {
        self.checkpoint = checkpoint
        self.onSubmit = onSubmit
    }

    /// Creates the interactive card for a checkpoint, or nil when it has no
    /// emoji slider data. Async because texture uploads to the GPU are async.
    /// On submit, the callback receives the recorded answer plus the emoji
    /// the knob ended closest to (under 50% = left, otherwise right).
    static func make(for checkpoint: Checkpoint, onSubmit: @escaping (_ answer: String, _ chosenEmoji: String) -> Void) async -> EmojiSliderBoardController? {
        guard checkpoint.hasEmojiSlider else { return nil }
        let controller = EmojiSliderBoardController(checkpoint: checkpoint, onSubmit: onSubmit)
        guard await controller.buildCard() else { return nil }
        return controller
    }

    func handleTap(on tappedEntity: Entity, at worldPosition: SIMD3<Float>?, cameraPosition: SIMD3<Float>) -> Bool {
        guard !isSubmitted else { return false }

        // Proximity gate: ignore taps from too far away.
        let boardPosition = rootEntity.position(relativeTo: nil)
        guard simd_distance(boardPosition, cameraPosition) <= SurveyCard.maxInteractionDistance else { return false }

        if tappedEntity === trackEntity, let worldPosition {
            moveKnob(toWorldPosition: worldPosition)
            return true
        }
        if tappedEntity === submitEntity {
            submit()
            return true
        }
        return false
    }

    func beginDrag(on entity: Entity, cameraPosition: SIMD3<Float>) -> Bool {
        guard !isSubmitted, entity === trackEntity else { return false }

        // Proximity gate: ignore drags from too far away.
        let boardPosition = rootEntity.position(relativeTo: nil)
        guard simd_distance(boardPosition, cameraPosition) <= SurveyCard.maxInteractionDistance else { return false }

        isDragging = true
        return true
    }

    /// Follows the finger while dragging: intersects the finger's ray with
    /// the card's plane, so the knob tracks smoothly even when the finger
    /// drifts off the thin track line.
    func updateDrag(rayOrigin: SIMD3<Float>, rayDirection: SIMD3<Float>) {
        guard isDragging, !isSubmitted, let trackEntity else { return }

        let planePoint = trackEntity.position(relativeTo: nil)
        let normal = rootEntity.orientation(relativeTo: nil).act(SIMD3<Float>(0, 0, 1))
        let denominator = simd_dot(rayDirection, normal)
        guard abs(denominator) > 0.0001 else { return }

        let t = simd_dot(planePoint - rayOrigin, normal) / denominator
        guard t > 0 else { return }

        moveKnob(toWorldPosition: rayOrigin + rayDirection * t)
    }

    func endDrag() {
        isDragging = false
    }

    /// Positions the knob at the tapped point along the track and derives the
    /// 0...1 slider value from it (0 = left emoji, 1 = right emoji).
    private func moveKnob(toWorldPosition worldPosition: SIMD3<Float>) {
        guard let trackEntity, trackWidthMeters > 0 else { return }
        let local = trackEntity.convert(position: worldPosition, from: nil)
        let normalized = min(max(local.x / trackWidthMeters + 0.5, 0), 1)
        value = normalized
        knobEntity?.position.x = trackCenterXMeters + (normalized - 0.5) * trackWidthMeters
    }

    private func submit() {
        guard let value, !isSubmitted else { return }
        isSubmitted = true
        // The knob's side decides the chosen emoji, benchmarked at 50%.
        let chosenEmoji = value < 0.5 ? checkpoint.emojiLeft : checkpoint.emojiRight
        // e.g. "82% (😡 → 😍)" — the percentage leans toward the right emoji.
        onSubmit("\(Int((value * 100).rounded()))% (\(checkpoint.emojiLeft) → \(checkpoint.emojiRight))", chosenEmoji)
        Task { @MainActor in
            await SurveyCard.swapToThankYouCard(on: self.rootEntity)
        }
    }

    private func buildCard() async -> Bool {
        let s = SurveyCard.metersPerPoint

        guard let question = await SurveyCard.renderPiece(QuestionTextView(text: checkpoint.question)),
              let leftEmoji = await SurveyCard.renderPiece(EmojiLabelView(emoji: checkpoint.emojiLeft)),
              let rightEmoji = await SurveyCard.renderPiece(EmojiLabelView(emoji: checkpoint.emojiRight)),
              let knob = await SurveyCard.renderPiece(SliderKnobView()),
              let submit = await SurveyCard.renderPiece(SubmitButtonView()) else { return false }

        let rowHeightPoints = max(knob.sizePoints.height, max(leftEmoji.sizePoints.height, rightEmoji.sizePoints.height))

        // Total card height in points.
        var contentHeight = question.sizePoints.height + SurveyCard.sectionSpacingPoints
        contentHeight += rowHeightPoints
        contentHeight += SurveyCard.sectionSpacingPoints + submit.sizePoints.height
        let cardHeight = contentHeight + SurveyCard.paddingPoints * 2

        rootEntity.addChild(SurveyCard.backgroundEntity(cardHeightPoints: cardHeight))

        // Stack downward from the top of the card.
        var cursor = Float(cardHeight) * s / 2 - Float(SurveyCard.paddingPoints) * s

        let questionEntity = SurveyCard.pieceEntity(question)
        questionEntity.position = [0, cursor - Float(question.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(questionEntity)
        cursor -= Float(question.sizePoints.height + SurveyCard.sectionSpacingPoints) * s

        // Slider row: left emoji, track, right emoji, with the knob on top.
        let rowCenterY = cursor - Float(rowHeightPoints) * s / 2
        let inner = SurveyCard.innerWidthPoints
        let leftWidth = leftEmoji.sizePoints.width
        let rightWidth = rightEmoji.sizePoints.width
        let trackWidthPoints = inner - leftWidth - rightWidth - Self.sliderSpacingPoints * 2
        trackWidthMeters = Float(trackWidthPoints) * s

        let leftEntity = SurveyCard.pieceEntity(leftEmoji)
        leftEntity.position = [Float(-inner / 2 + leftWidth / 2) * s, rowCenterY, 0.002]
        rootEntity.addChild(leftEntity)

        let rightEntity = SurveyCard.pieceEntity(rightEmoji)
        rightEntity.position = [Float(inner / 2 - rightWidth / 2) * s, rowCenterY, 0.002]
        rootEntity.addChild(rightEntity)

        let trackCenterXPoints = -inner / 2 + leftWidth + Self.sliderSpacingPoints + trackWidthPoints / 2
        trackCenterXMeters = Float(trackCenterXPoints) * s

        let trackMesh = MeshResource.generatePlane(
            width: trackWidthMeters,
            height: Float(Self.trackHeightPoints) * s,
            cornerRadius: Float(Self.trackHeightPoints / 2) * s
        )
        let track = ModelEntity(mesh: trackMesh, materials: [UnlitMaterial(color: UIColor(white: 0.9, alpha: 1))])
        track.position = [trackCenterXMeters, rowCenterY, 0.002]
        // The collision box is much taller than the visual track line, so the
        // whole slider row is an easy tap target.
        track.collision = CollisionComponent(shapes: [
            .generateBox(width: trackWidthMeters, height: Float(rowHeightPoints) * s, depth: 0.01)
        ])
        rootEntity.addChild(track)
        trackEntity = track

        // Knob starts at the center. It has no collision, so taps around it
        // fall through to the track behind it.
        let knobDiameterMeters = Float(knob.sizePoints.width) * s
        let knobMesh = MeshResource.generatePlane(
            width: knobDiameterMeters,
            height: knobDiameterMeters,
            cornerRadius: knobDiameterMeters / 2
        )
        let knobModel = ModelEntity(mesh: knobMesh, materials: [knob.material])
        knobModel.position = [trackCenterXMeters, rowCenterY, 0.003]
        rootEntity.addChild(knobModel)
        knobEntity = knobModel

        cursor -= Float(rowHeightPoints + SurveyCard.sectionSpacingPoints) * s

        let submitButton = SurveyCard.pieceEntity(submit, tappable: true)
        submitButton.position = [0, cursor - Float(submit.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(submitButton)
        submitEntity = submitButton

        return true
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

private struct EmojiLabelView: View {
    let emoji: String

    var body: some View {
        Text(emoji)
            .font(.system(size: 24))
            .padding(2)
            .background(Color.white)
    }
}

private struct SliderKnobView: View {
    var body: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(tanyaPurple, lineWidth: 5))
            .frame(width: 30, height: 30)
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
