import RealityKit
import UIKit

/// Builds the floating AR question board shown at an MCQ checkpoint.
///
/// The board is meant to be rotated toward the camera every frame with
/// `yawToFace(cameraPosition:)`, so the citizen can read the question from
/// any direction instead of seeing an invisible back side. Yaw-only rotation
/// (around the world Y axis) is used instead of `BillboardComponent` on
/// purpose: a full billboard pitches and rolls with the camera (the sensor
/// is natively landscape), which makes the board lie flat on the ground when
/// viewed from above. Yaw-only keeps it standing upright like a beacon.
///
/// All meshes are generated programmatically (no bundled assets) to keep
/// the App Clip footprint small.
enum MCQBoardEntity {
    
    // Layout constants, in meters.
    private static let contentWidth: Float = 0.8
    private static let padding: Float = 0.05
    private static let lineSpacing: Float = 0.025
    private static let questionFontSize: CGFloat = 0.05
    private static let optionFontSize: CGFloat = 0.04
    
    /// Creates the board for a checkpoint, or nil when it has no MCQ data.
    static func make(for checkpoint: Checkpoint) -> Entity? {
        guard checkpoint.hasMCQ else { return nil }
        
        // The question line, followed by one lettered line per option.
        var lines: [ModelEntity] = [
            makeTextLine(checkpoint.question,
                         fontSize: questionFontSize,
                         weight: .bold,
                         color: .white)
        ]
        for (index, option) in checkpoint.surveyOptions.enumerated() {
            let letter = Character(UnicodeScalar(UInt8(65 + min(index, 25))))
            lines.append(makeTextLine("\(letter). \(option)",
                                      fontSize: optionFontSize,
                                      weight: .regular,
                                      color: UIColor(white: 0.85, alpha: 1)))
        }
        
        // Stack the lines downward from y = 0, left-aligned to the board edge.
        // Text meshes pivot at their glyph bounds, so each line is offset by
        // its measured bounds to get consistent spacing.
        let content = Entity()
        var cursorY: Float = 0
        for (index, line) in lines.enumerated() {
            let bounds = line.model?.mesh.bounds ?? BoundingBox()
            line.position = [
                -contentWidth / 2 - bounds.min.x,
                cursorY - bounds.max.y,
                0.005
            ]
            content.addChild(line)
            cursorY -= (bounds.max.y - bounds.min.y) + lineSpacing
            if index == 0 {
                // Extra gap between the question and the options.
                cursorY -= lineSpacing
            }
        }
        let contentHeight = -(cursorY + lineSpacing)
        
        // Dark rounded backdrop sitting just behind the text.
        let backdropMesh = MeshResource.generatePlane(
            width: contentWidth + padding * 2,
            height: contentHeight + padding * 2,
            cornerRadius: 0.04
        )
        let backdropMaterial = UnlitMaterial(color: UIColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1))
        let backdrop = ModelEntity(mesh: backdropMesh, materials: [backdropMaterial])
        backdrop.position = [0, -contentHeight / 2, 0]
        content.addChild(backdrop)
        
        // Center the content vertically so the board pivots around its middle.
        let board = Entity()
        content.position.y = contentHeight / 2
        board.addChild(content)
        
        return board
    }
    
    /// Generates a single word-wrapped text line as an unlit model entity.
    private static func makeTextLine(_ string: String,
                                     fontSize: CGFloat,
                                     weight: UIFont.Weight,
                                     color: UIColor) -> ModelEntity {
        let mesh = MeshResource.generateText(
            string,
            extrusionDepth: 0.002,
            font: .systemFont(ofSize: fontSize, weight: weight),
            containerFrame: CGRect(x: 0, y: 0, width: CGFloat(contentWidth), height: 4),
            alignment: .left,
            lineBreakMode: .byWordWrapping
        )
        return ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)])
    }
}

extension Entity {
    /// Rotates the entity around the world Y axis so its front (+Z) points
    /// toward the camera, while staying upright relative to gravity. Call
    /// this every frame (e.g. from a `SceneEvents.Update` subscription) to
    /// keep AR text readable from any direction and any phone orientation.
    func yawToFace(cameraPosition: SIMD3<Float>) {
        let worldPosition = position(relativeTo: nil)
        let direction = cameraPosition - worldPosition
        // Ignore the degenerate case of the camera being directly above/below.
        guard abs(direction.x) > 0.0001 || abs(direction.z) > 0.0001 else { return }
        let yaw = atan2(direction.x, direction.z)
        setOrientation(simd_quatf(angle: yaw, axis: [0, 1, 0]), relativeTo: nil)
    }
}
