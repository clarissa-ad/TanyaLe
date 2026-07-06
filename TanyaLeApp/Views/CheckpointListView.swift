import SwiftUI

struct CheckpointListView: View {
    @ObservedObject private var db = MockDatabaseService.shared
    
    var body: some View {
        List {
            if db.checkpoints.isEmpty {
                Text("No checkpoints created yet.")
                    .foregroundColor(.gray)
            } else {
                ForEach(db.checkpoints) { checkpoint in
                    NavigationLink(destination: CheckpointEditView(checkpoint: checkpoint)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(checkpoint.title)
                                .font(.headline)
                            Text(checkpoint.taskDescription)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                            
                            if checkpoint.interactionType != .none {
                                Text(checkpoint.interactionType.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteCheckpoint)
            }
        }
        .navigationTitle("Manage Checkpoints")
        .navigationBarItems(trailing: EditButton())
    }
    
    private func deleteCheckpoint(at offsets: IndexSet) {
        offsets.forEach { index in
            let cp = db.checkpoints[index]
            db.deleteCheckpoint(cp.id)
        }
    }
}
