import Foundation
import CoreLocation

enum InteractionType: String, Codable, CaseIterable, Identifiable {
    case info = "Information Only"
    case multipleChoice = "Multiple Choice Question"
    case photo = "Photo Capture"
    
    var id: String { self.rawValue }
}

/// Represents a single task/checkpoint placed by Pak RT in the real world.
struct Checkpoint: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var taskDescription: String
    var interactionType: InteractionType = .info
    var surveyOptions: [String] = []
    
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
