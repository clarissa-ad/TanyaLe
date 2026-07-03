import Foundation
import CoreLocation

/// Represents a single task/checkpoint placed by Pak RT in the real world.
struct Checkpoint: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var taskDescription: String
    
    // Relative physical offsets from the AR World Origin (App Clip scan location)
    // All values are in meters.
    var relativeX: Float
    var relativeY: Float
    var relativeZ: Float
    
    // Equatable conformance
    static func == (lhs: Checkpoint, rhs: Checkpoint) -> Bool {
        lhs.id == rhs.id
    }
}
