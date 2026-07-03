import SwiftUI

struct CheckpointEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var db = MockDatabaseService.shared
    
    let checkpointId: UUID
    
    @State private var title: String
    @State private var taskDescription: String
    @State private var surveyOptions: [String]
    
    @State private var newOption: String = ""
    
    init(checkpoint: Checkpoint) {
        self.checkpointId = checkpoint.id
        _title = State(initialValue: checkpoint.title)
        _taskDescription = State(initialValue: checkpoint.taskDescription)
        _surveyOptions = State(initialValue: checkpoint.surveyOptions)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Checkpoint Details")) {
                TextField("Title", text: $title)
                TextField("Description", text: $taskDescription)
            }
            
            Section(header: Text("Multiple Choice Options (Optional)"), footer: Text("Add survey choices for the user to select when they reach this checkpoint.")) {
                ForEach(surveyOptions.indices, id: \.self) { index in
                    HStack {
                        Text("\(index + 1).")
                            .foregroundColor(.gray)
                        TextField("Option", text: Binding(
                            get: { self.surveyOptions[index] },
                            set: { self.surveyOptions[index] = $0 }
                        ))
                    }
                }
                .onDelete { offsets in
                    surveyOptions.remove(atOffsets: offsets)
                }
                
                HStack {
                    TextField("Add new option...", text: $newOption)
                    Button(action: {
                        if !newOption.isEmpty {
                            surveyOptions.append(newOption)
                            newOption = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .navigationTitle("Edit Checkpoint")
        .navigationBarItems(trailing: Button("Save") {
            saveChanges()
        })
    }
    
    private func saveChanges() {
        if let index = db.checkpoints.firstIndex(where: { $0.id == checkpointId }) {
            var updated = db.checkpoints[index]
            updated.title = title
            updated.taskDescription = taskDescription
            updated.surveyOptions = surveyOptions.filter { !$0.isEmpty } // Clean up empty options
            db.updateCheckpoint(updated)
        }
        presentationMode.wrappedValue.dismiss()
    }
}
