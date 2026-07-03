import Foundation
import Combine
import CoreLocation

/// ⚠️ TEMPORARY DEV FILE ⚠️
/// This is a mock database service for local development and testing only.
/// It holds checkpoints in memory so both Maker and User views can share state
/// without needing an active CloudKit connection.
/// DO NOT USE IN PRODUCTION.
class MockDatabaseService: ObservableObject {
    static let shared = MockDatabaseService()
    
    @Published var checkpoints: [Checkpoint] = []
    
    // The locked GPS coordinate c where the AR Origin was set
    @Published var surveyOrigin: CLLocationCoordinate2D?
    
    private init() {
        checkpoints = [
            Checkpoint(
                title: "Trash Can Checkpoint",
                taskDescription: "Does this look good?",
                interactionType: .multipleChoice,
                surveyOptions: ["Yes, looks good", "Needs replacement", "Overflowing"],
                latitude: -6.200000,
                longitude: 106.816666,
                relativeX: 0,
                relativeY: 0,
                relativeZ: -3.0
            )
        ]
    }
    
    func saveCheckpoint(_ checkpoint: Checkpoint) {
        checkpoints.append(checkpoint)
        print("Mock DB: Saved checkpoint \(checkpoint.title)")
    }
    
    func deleteCheckpoint(_ id: UUID) {
        checkpoints.removeAll { $0.id == id }
        print("Mock DB: Deleted checkpoint \(id)")
    }
    
    func updateCheckpoint(_ checkpoint: Checkpoint) {
        if let index = checkpoints.firstIndex(where: { $0.id == checkpoint.id }) {
            checkpoints[index] = checkpoint
        }
    }
}
