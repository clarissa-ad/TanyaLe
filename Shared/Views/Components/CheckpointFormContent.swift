import SwiftUI

struct CheckpointFormContent: View {
    @Binding var title: String
    @Binding var taskDescription: String
    @Binding var interactionType: InteractionType
    @Binding var surveyOptions: [String]
    
    @State private var newOption: String = ""
    
    var body: some View {
        Section(header: Text("Checkpoint Details")) {
            TextField("Title", text: $title)
            TextField("Description", text: $taskDescription)
            
            Picker("Interaction Type", selection: $interactionType) {
                ForEach(InteractionType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
        }
        
        if interactionType == .multipleChoice {
            Section(header: Text("Multiple Choice Options"), footer: Text("Add survey choices for the user to select when they reach this checkpoint.")) {
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
    }
}
