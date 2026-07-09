import SwiftUI

struct CheckpointListView: View {
    /// When set, only this journey's checkpoints are listed, and deleting a
    /// checkpoint also detaches it from the journey. `nil` lists everything
    /// (sandbox/prototype flows).
    var journey: Journey?

    var db = MockDatabaseService.shared
    var journeyService = JourneyService.shared

    /// Reads the journey fresh from the service so checkpoints added after
    /// this view was created still show up.
    private var checkpoints: [Checkpoint] {
        guard let journey,
              let fresh = journeyService.getJourney(by: journey.id) else {
            return db.checkpoints
        }
        return db.checkpoints.filter { fresh.checkpointIDs.contains($0.id) }
    }

    var body: some View {
        List {
            if checkpoints.isEmpty {
                Text("No checkpoints created yet.")
                    .foregroundStyle(.gray)
            } else {
                ForEach(checkpoints) { checkpoint in
                    NavigationLink(destination: CheckpointEditView(checkpoint: checkpoint)) {
                        CheckpointRowView(checkpoint: checkpoint)
                    }
                }
                .onDelete(perform: deleteCheckpoint)
            }
        }
        .navigationTitle("Manage Checkpoints")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
    }

    private func deleteCheckpoint(at offsets: IndexSet) {
        offsets.forEach { index in
            // Index into the *filtered* list, not the full DB array.
            let cp = checkpoints[index]
            db.deleteCheckpoint(cp.id)
            if let journey {
                journeyService.removeCheckpoint(cp.id, from: journey.id)
            }
        }
    }
}
