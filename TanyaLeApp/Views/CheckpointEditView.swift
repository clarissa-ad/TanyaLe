import SwiftUI
import UIKit

struct CheckpointEditView: View {
    @Environment(\.dismiss) private var dismiss
    private var db = MockDatabaseService.shared

    let checkpointId: UUID

    @State private var title: String
    @State private var taskDescription: String
    @State private var interactionType: Checkpoint.InteractionType
    @State private var question: String
    @State private var surveyOptions: [String]
    @State private var emojiLeft: String
    @State private var emojiRight: String
    @State private var selectedAssetId: String?
    @State private var showingAssetPicker = false
    @State private var promptPhotoID: String?
    
    @State private var showingImagePicker = false
    @State private var selectedPromptPhoto: UIImage?

    init(checkpoint: Checkpoint) {
        self.checkpointId = checkpoint.id
        _title = State(initialValue: checkpoint.title)
        _taskDescription = State(initialValue: checkpoint.taskDescription)
        _interactionType = State(initialValue: checkpoint.interactionType)
        _question = State(initialValue: checkpoint.question)
        _surveyOptions = State(initialValue: checkpoint.surveyOptions)
        _emojiLeft = State(initialValue: checkpoint.emojiLeft)
        _emojiRight = State(initialValue: checkpoint.emojiRight)
        _selectedAssetId = State(initialValue: checkpoint.selectedAssetId)
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
                showingImagePicker: $showingImagePicker,
                selectedAssetId: $selectedAssetId,
                showingAssetPicker: $showingAssetPicker
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
        .dismissKeyboardOnTap()
        .navigationTitle("Edit Checkpoint")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveChanges()
                }
            }
        }
        .sheet(isPresented: $showingAssetPicker) {
            AssetPickerView(selectedAssetId: $selectedAssetId)
        }
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
            updated.selectedAssetId = selectedAssetId
            updated.promptPhotoID = promptPhotoID
            db.updateCheckpoint(updated)
        }
        dismiss()
    }
}
