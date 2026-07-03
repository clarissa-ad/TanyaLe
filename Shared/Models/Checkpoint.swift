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

        var id: String { rawValue }
    }

    var id: UUID = UUID()
    var title: String
    var taskDescription: String
    var interactionType: InteractionType = .none

    // MCQ configuration (used when interactionType == .mcq)
    var question: String = ""
    var surveyOptions: [String] = []

    /// Whether this checkpoint has a complete multiple choice question to display.
    var hasMCQ: Bool {
        interactionType == .mcq && !question.isEmpty && surveyOptions.count >= 2
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
