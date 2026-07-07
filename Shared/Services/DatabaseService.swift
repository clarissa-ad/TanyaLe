import Foundation
import Combine
import CoreLocation
import Supabase

@MainActor
class DatabaseService: ObservableObject {
    static let shared = DatabaseService()
    
    @Published var checkpoints: [Checkpoint] = []
    @Published var responses: [UUID: String] = [:]
    @Published var surveyOrigin: CLLocationCoordinate2D?
    
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.projectURL,
            supabaseKey: SupabaseConfig.anonKey
        )
        
        Task {
            await fetchCheckpoints()
        }
    }
    
    func fetchCheckpoints() async {
        do {
            let fetchedCheckpoints: [Checkpoint] = try await client
                .from("checkpoints")
                .select()
                .execute()
                .value
            
            self.checkpoints = fetchedCheckpoints
            print("Supabase: Fetched \(fetchedCheckpoints.count) checkpoints.")
        } catch {
            print("Supabase Error fetching checkpoints: \(error)")
        }
    }
    
    func saveCheckpoint(_ checkpoint: Checkpoint) {
        // Optimistic update
        checkpoints.append(checkpoint)
        
        Task {
            do {
                try await client
                    .from("checkpoints")
                    .insert(checkpoint)
                    .execute()
                print("Supabase: Saved checkpoint \(checkpoint.title)")
            } catch {
                print("Supabase Error saving checkpoint: \(error)")
                // Revert optimistic update on failure if needed
                await fetchCheckpoints()
            }
        }
    }
    
    func updateCheckpoint(_ checkpoint: Checkpoint) {
        // Optimistic update
        if let index = checkpoints.firstIndex(where: { $0.id == checkpoint.id }) {
            checkpoints[index] = checkpoint
        }
        
        Task {
            do {
                try await client
                    .from("checkpoints")
                    .update(checkpoint)
                    .eq("id", value: checkpoint.id)
                    .execute()
                print("Supabase: Updated checkpoint \(checkpoint.id)")
            } catch {
                print("Supabase Error updating checkpoint: \(error)")
                await fetchCheckpoints()
            }
        }
    }
    
    func deleteCheckpoint(_ id: UUID) {
        // Optimistic update
        checkpoints.removeAll { $0.id == id }
        
        Task {
            do {
                try await client
                    .from("checkpoints")
                    .delete()
                    .eq("id", value: id)
                    .execute()
                print("Supabase: Deleted checkpoint \(id)")
            } catch {
                print("Supabase Error deleting checkpoint: \(error)")
                await fetchCheckpoints()
            }
        }
    }
    
    func saveResponse(checkpointID: UUID, answer: String) {
        // Store locally for UI immediate update
        responses[checkpointID] = answer
        
        struct ResponseInsert: Codable {
            let checkpoint_id: UUID
            let answer: String
        }
        
        Task {
            do {
                let response = ResponseInsert(checkpoint_id: checkpointID, answer: answer)
                try await client
                    .from("checkpoint_responses")
                    .insert(response)
                    .execute()
                print("Supabase: Saved MCQ answer '\(answer)' for checkpoint \(checkpointID)")
            } catch {
                print("Supabase Error saving response: \(error)")
            }
        }
    }
}
