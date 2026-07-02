import Foundation
import Combine

/// ⚠️ TEMPORARY DEV FILE ⚠️
/// This is a mock database service for local development and testing only.
/// It holds checkpoints in memory so both Maker and User views can share state
/// without needing an active CloudKit connection.
/// DO NOT USE IN PRODUCTION.
class MockDatabaseService: ObservableObject {
    static let shared = MockDatabaseService()
    
    @Published var checkpoints: [Checkpoint] = []
    
    private init() {
        // Load some dummy data for testing if needed
        checkpoints = [
            Checkpoint(
                title: "Trash Cans Survey",
                taskDescription: "Does this look good?",
                latitude: -6.200000,
                longitude: 106.816666
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
}
