import SwiftUI

struct CheckpointEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var db = MockDatabaseService.shared
    
    let checkpointId: UUID
    
    @State private var title: String
    @State private var taskDescription: String
    @State private var interactionType: InteractionType
    @State private var surveyOptions: [String]
    
    init(checkpoint: Checkpoint) {
        self.checkpointId = checkpoint.id
        _title = State(initialValue: checkpoint.title)
        _taskDescription = State(initialValue: checkpoint.taskDescription)
        _interactionType = State(initialValue: checkpoint.interactionType)
        _surveyOptions = State(initialValue: checkpoint.surveyOptions)
    }
    
    var body: some View {
        Form {
            CheckpointFormContent(
                title: $title,
                taskDescription: $taskDescription,
                interactionType: $interactionType,
                surveyOptions: $surveyOptions
            )
        }
        .navigationTitle("Edit Checkpoint")
        .navigationBarItems(trailing: HStack {
            EditButton()
            Button("Save") {
                saveChanges()
            }
        })
    }
    
    private func saveChanges() {
        if let index = db.checkpoints.firstIndex(where: { $0.id == checkpointId }) {
            var updated = db.checkpoints[index]
            updated.title = title
            updated.taskDescription = taskDescription
            updated.interactionType = interactionType
            updated.surveyOptions = surveyOptions.filter { !$0.isEmpty } // Clean up empty options
            db.updateCheckpoint(updated)
        }
        presentationMode.wrappedValue.dismiss()
    }
}
