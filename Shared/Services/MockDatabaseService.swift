import Foundation
import Observation
import CoreLocation

/// ⚠️ TEMPORARY DEV FILE ⚠️
/// This is a mock database service for local development and testing only.
/// It holds checkpoints in memory so both Maker and User views can share state
/// without needing an active CloudKit connection.
/// DO NOT USE IN PRODUCTION.
@Observable
class MockDatabaseService {
    static let shared = MockDatabaseService()
    
    var checkpoints: [Checkpoint] = []

    /// Selected MCQ answer per checkpoint ID (in-memory only).
    var responses: [UUID: String] = [:]

    /// Like/Dislike vote tallies per checkpoint (in-memory only). Kept
    /// separate from `responses` since that's a single "last answer" slot —
    /// Like/Dislike needs a running count of both sides, not just the most
    /// recent vote.
    var likeDislikeVotes: [UUID: (likes: Int, dislikes: Int)] = [:]

    // The locked GPS coordinate c where the AR Origin was set
    var surveyOrigin: CLLocationCoordinate2D?
    
    private init() {
        checkpoints = [
            Checkpoint(
                title: "Trash Can Checkpoint",
                taskDescription: "Does this look good?",
                interactionType: .mcq,
                question: "How is the trash can situation here?",
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
    
    func saveResponse(checkpointID: UUID, answer: String) {
        responses[checkpointID] = answer
        print("Mock DB: Saved MCQ answer '\(answer)' for checkpoint \(checkpointID)")
    }

    func recordVote(checkpointID: UUID, isLike: Bool) {
        var tally = likeDislikeVotes[checkpointID] ?? (likes: 0, dislikes: 0)
        if isLike {
            tally.likes += 1
        } else {
            tally.dislikes += 1
        }
        likeDislikeVotes[checkpointID] = tally
        print("Mock DB: Recorded \(isLike ? "like" : "dislike") for checkpoint \(checkpointID). Now \(tally.likes) likes, \(tally.dislikes) dislikes")
    }

    func updateCheckpoint(_ checkpoint: Checkpoint) {
        if let index = checkpoints.firstIndex(where: { $0.id == checkpoint.id }) {
            checkpoints[index] = checkpoint
        }
    }
}
