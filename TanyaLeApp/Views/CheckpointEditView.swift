import SwiftUI

struct CheckpointEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var db = MockDatabaseService.shared
    
    let checkpointId: UUID
    
    @State private var title: String
    @State private var taskDescription: String
    @State private var interactionType: Checkpoint.InteractionType
    @State private var question: String
    @State private var surveyOptions: [String]

    @State private var newOption: String = ""

    init(checkpoint: Checkpoint) {
        self.checkpointId = checkpoint.id
        _title = State(initialValue: checkpoint.title)
        _taskDescription = State(initialValue: checkpoint.taskDescription)
        _interactionType = State(initialValue: checkpoint.interactionType)
        _question = State(initialValue: checkpoint.question)
        _surveyOptions = State(initialValue: checkpoint.surveyOptions)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Checkpoint Details")) {
                TextField("Title", text: $title)
                TextField("Description", text: $taskDescription)
            }
            
            Section(header: Text("Interaction"), footer: Text("Choose what the citizen does when they reach this checkpoint. A plain checkpoint just needs to be visited.")) {
                Picker("Type", selection: $interactionType) {
                    ForEach(Checkpoint.InteractionType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }

            if interactionType == .mcq {
                Section(header: Text("Multiple Choice Question"), footer: Text("The question is shown on the AR board; add at least 2 choices for the user to select.")) {
                    TextField("Question", text: $question)

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
            } else if interactionType == .photobooth {
                Section {
                    Text("Photobooth configuration coming soon.")
                        .foregroundColor(.secondary)
                }
            } else if interactionType == .emojiSlider {
                Section {
                    Text("Emoji slider configuration coming soon.")
                        .foregroundColor(.secondary)
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
            updated.interactionType = interactionType
            updated.question = question.trimmingCharacters(in: .whitespaces)
            updated.surveyOptions = surveyOptions.filter { !$0.isEmpty } // Clean up empty options
            db.updateCheckpoint(updated)
        }
        presentationMode.wrappedValue.dismiss()
    }
}
