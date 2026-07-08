import Foundation
import CoreLocation

/// Represents a single task/checkpoint placed by Pak RT in the real world.
struct Checkpoint: Identifiable, Codable, Equatable {
    /// The interaction a citizen performs at this checkpoint. A checkpoint is
    /// dropped as a plain pin (.none); the maker assigns and configures the
    /// interaction later from the checkpoint list.
    enum InteractionType: String, Codable, CaseIterable, Identifiable {
        case none = "None"
        case mcq = "Multiple Choice"
        case photobooth = "Photobooth"
        case emojiSlider = "Emoji Slider"
        case likedislike = "Like/Dislike"

        var id: String { rawValue }
    }

    var id: UUID = UUID()
    var title: String
    var taskDescription: String
    var interactionType: InteractionType = .none

    // MCQ configuration (used when interactionType == .mcq)
    var question: String = ""
    var surveyOptions: [String] = []

    // Emoji slider configuration (used when interactionType == .emojiSlider).
    // The citizen slides between the two emoji to answer the question.
    var emojiLeft: String = "😡"
    var emojiRight: String = "😍"

    // Like/Dislike configuration (used when interactionType == .likedislike).
    // Stores a reference to an Asset3D by id rather than a copy of its data,
    // so MockAssetService stays the single source of truth — editing an
    // asset's description keeps every checkpoint that references it in sync.
    // Reuses `question` above for the custom Like/Dislike question.
    var selectedAssetId: String?

    /// Whether this checkpoint has a complete multiple choice question to display.
    var hasMCQ: Bool {
        interactionType == .mcq && !question.isEmpty && surveyOptions.count >= 2
    }

    /// Whether this checkpoint has a complete emoji slider to display.
    var hasEmojiSlider: Bool {
        interactionType == .emojiSlider && !question.isEmpty && !emojiLeft.isEmpty && !emojiRight.isEmpty
    }

    /// Whether this checkpoint has a complete Like/Dislike setup to display.
    var hasLikeDislike: Bool {
        interactionType == .likedislike && !question.isEmpty && selectedAssetId != nil
    }
    
    // GPS Coordinates (for 2D Map)
    var latitude: Double
    var longitude: Double
    
    // Relative physical offsets from the AR World Origin (App Clip scan location)
    // All values are in meters.
    var relativeX: Float
    var relativeY: Float
    var relativeZ: Float
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Equatable conformance
    static func == (lhs: Checkpoint, rhs: Checkpoint) -> Bool {
        lhs.id == rhs.id
    }
}
