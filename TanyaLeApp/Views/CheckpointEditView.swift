import SwiftUI
import UIKit

struct CheckpointEditView: View {
    @Environment(\.presentationMode) var presentationMode
    private var db = MockDatabaseService.shared
    
    let checkpointId: UUID
    
    @State private var title: String
    @State private var taskDescription: String
    @State private var interactionType: Checkpoint.InteractionType
    @State private var question: String
    @State private var surveyOptions: [String]
    @State private var emojiLeft: String
    @State private var emojiRight: String
    @State private var promptPhotoID: String?
    
    @State private var showingImagePicker = false
    @State private var selectedPromptPhoto: UIImage?

    @State private var newOption: String = ""
    init(checkpoint: Checkpoint) {
        self.checkpointId = checkpoint.id
        _title = State(initialValue: checkpoint.title)
        _taskDescription = State(initialValue: checkpoint.taskDescription)
        _interactionType = State(initialValue: checkpoint.interactionType)
        _question = State(initialValue: checkpoint.question)
        _surveyOptions = State(initialValue: checkpoint.surveyOptions)
        _emojiLeft = State(initialValue: checkpoint.emojiLeft)
        _emojiRight = State(initialValue: checkpoint.emojiRight)
        _promptPhotoID = State(initialValue: checkpoint.promptPhotoID)
    }
    
    var body: some View {
        Form {
            CheckpointFormContent(
                title: $title,
                taskDescription: $taskDescription,
                interactionType: $interactionType,
                question: $question,
                surveyOptions: $surveyOptions,
                emojiLeft: $emojiLeft,
                emojiRight: $emojiRight,
                promptPhotoID: $promptPhotoID,
                showingImagePicker: $showingImagePicker
            )
            
            if interactionType == .photobooth, let cp = db.checkpoints.first(where: { $0.id == checkpointId }) {
                Section {
                    NavigationLink(destination: MakerResponsesView(checkpoint: cp)) {
                        Text("View Photos")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Edit Checkpoint")
        .navigationBarItems(trailing: HStack {
            EditButton()
            Button("Save") {
                saveChanges()
            }
        })
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedPromptPhoto) {
                if let image = selectedPromptPhoto {
                    let id = UUID().uuidString
                    MockPhotoService.shared.savePromptPhoto(image: image, id: id)
                    promptPhotoID = id
                }
            }
        }
    }
    
    private func saveChanges() {
        if let index = db.checkpoints.firstIndex(where: { $0.id == checkpointId }) {
            var updated = db.checkpoints[index]
            updated.title = title
            updated.taskDescription = taskDescription
            updated.interactionType = interactionType
            updated.question = question.trimmingCharacters(in: .whitespaces)
            updated.surveyOptions = surveyOptions.filter { !$0.isEmpty } // Clean up empty options
            // Keep only the first emoji of each field; fall back to defaults.
            let left = emojiLeft.trimmingCharacters(in: .whitespaces)
            let right = emojiRight.trimmingCharacters(in: .whitespaces)
            updated.emojiLeft = left.isEmpty ? "😡" : String(left.prefix(1))
            updated.emojiRight = right.isEmpty ? "😍" : String(right.prefix(1))
            updated.promptPhotoID = promptPhotoID
            db.updateCheckpoint(updated)
        }
        presentationMode.wrappedValue.dismiss()
    }
}

/// A text field that opens the emoji keyboard directly when focused.
///
/// UIKit has no public emoji `UIKeyboardType`, but a responder can report the
/// emoji input mode as its preferred one via `textInputMode` — the system
/// then presents the emoji keyboard by default (the user can still switch
/// keyboards with the globe key).
private struct EmojiTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> EmojiUITextField {
        let field = EmojiUITextField()
        field.placeholder = placeholder
        field.textAlignment = .center
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: EmojiUITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    class Coordinator: NSObject {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func textChanged(_ sender: UITextField) {
            text.wrappedValue = sender.text ?? ""
        }
    }

    class EmojiUITextField: UITextField {
        // A non-nil identifier lets UIKit restore this field's input mode
        // instead of the user's default keyboard.
        override var textInputContextIdentifier: String? { "" }

        override var textInputMode: UITextInputMode? {
            UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
        }
    }
}
