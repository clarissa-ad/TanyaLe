import SwiftUI

struct CheckpointFormContent: View {
    @Binding var title: String
    @Binding var taskDescription: String
    @Binding var interactionType: Checkpoint.InteractionType
    @Binding var question: String
    @Binding var surveyOptions: [String]
    @Binding var emojiLeft: String
    @Binding var emojiRight: String
    @Binding var promptPhotoID: String?
    @Binding var showingImagePicker: Bool
    
    @State private var newOption: String = ""
    
    var body: some View {
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
            Section(header: Text("Photobooth Prompt"), footer: Text("The text prompt and reference photo shown to citizens when taking a photo.")) {
                TextField("Text Prompt (e.g. Take a selfie...)", text: $question)
                
                HStack {
                    if let id = promptPhotoID, let image = MockPhotoService.shared.fetchPromptPhoto(id: id) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(Image(systemName: "photo").foregroundColor(.gray))
                    }
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Text(promptPhotoID == nil ? "Upload Prompt Photo" : "Change Prompt Photo")
                    }
                }
            }
        } else if interactionType == .emojiSlider {
            Section(header: Text("Emoji Slider"), footer: Text("The citizen slides between the two emoji to answer the question. Use the arrows to swap sides.")) {
                TextField("Question", text: $question)

                HStack {
                    TextField("Left", text: $emojiLeft)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        let temp = emojiLeft
                        emojiLeft = emojiRight
                        emojiRight = temp
                    }) {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)

                    TextField("Right", text: $emojiRight)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}
