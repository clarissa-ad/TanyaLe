import SwiftUI

struct CheckpointFormContent: View {
    @Binding var title: String
    @Binding var taskDescription: String
    @Binding var interactionType: Checkpoint.InteractionType
    @Binding var question: String
    @Binding var surveyOptions: [String]
    @Binding var emojiLeft: String
    @Binding var emojiRight: String

    // Tracks whether the extra 2 slots (5 & 6) are visible.
    @State private var showExtraOptions = false

    var body: some View {
        Section(header: Text("Checkpoint Details")) {
            TextField("Title", text: $title)
        }
        Section(header: Text("Checkpoint Description")) {
            TextField("Description (optional)", text: $taskDescription)
        }

        Section(
            header: Text("Interaction"),
            footer: Text("Choose what the citizen does when they reach this checkpoint. A plain checkpoint just needs to be visited.")
        ) {
            Picker("Type", selection: $interactionType) {
                ForEach(Checkpoint.InteractionType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
        }

        if interactionType == .mcq {
            Section(
                header: Text("Multiple Choice Question"),
                footer: Text("Options 1 and 2 are required. Tap \"Add More Answers\" to unlock two extra slots (6 max).")
            ) {
                TextField("Question", text: $question)

                optionField(at: 0, placeholder: "Option 1 (required)")
                optionField(at: 1, placeholder: "Option 2 (required)")
                optionField(at: 2, placeholder: "Option 3 (optional)")
                optionField(at: 3, placeholder: "Option 4 (optional)")

                if showExtraOptions {
                    optionField(at: 4, placeholder: "Option 5 (optional)")
                    optionField(at: 5, placeholder: "Option 6 (optional)")
                } else {
                    Button(action: {
                        ensureCapacity(6)
                        showExtraOptions = true
                    }) {
                        Label("Add More Answers", systemImage: "plus.circle")
                    }
                }
            }
            .onAppear { setupMCQSlots() }
            .onChange(of: interactionType) { _, newType in
                if newType == .mcq { setupMCQSlots() }
            }
        } else if interactionType == .photobooth {
            Section {
                Text("Photobooth configuration coming soon.")
                    .foregroundColor(.secondary)
            }
        } else if interactionType == .emojiSlider {
            Section(
                header: Text("Emoji Slider"),
                footer: Text("The citizen slides between the two emoji to answer the question. Use the arrows to swap sides.")
            ) {
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

    // MARK: - Helpers

    @ViewBuilder
    private func optionField(at index: Int, placeholder: String) -> some View {
        TextField(placeholder, text: optionBinding(at: index))
    }

    private func optionBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { index < surveyOptions.count ? surveyOptions[index] : "" },
            set: {
                ensureCapacity(index + 1)
                surveyOptions[index] = $0
            }
        )
    }

    private func ensureCapacity(_ count: Int) {
        while surveyOptions.count < count {
            surveyOptions.append("")
        }
    }

    /// Pads the options array to 4 slots and restores the "show extra" state
    /// if a checkpoint was loaded with more than 4 options already saved.
    private func setupMCQSlots() {
        if surveyOptions.count > 4 {
            showExtraOptions = true
            ensureCapacity(6)
        } else {
            ensureCapacity(4)
        }
    }
}
