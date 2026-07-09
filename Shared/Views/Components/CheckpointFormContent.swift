import SwiftUI
import UIKit

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
                    EmojiTextField(placeholder: "Left", text: $emojiLeft)

                    Button(action: {
                        let temp = emojiLeft
                        emojiLeft = emojiRight
                        emojiRight = temp
                    }) {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)

                    EmojiTextField(placeholder: "Right", text: $emojiRight)
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

// MARK: - Keyboard helpers

extension View {
    /// Lets the user dismiss the keyboard by tapping anywhere else on the
    /// form, or by scrolling it.
    ///
    /// Implemented with a UIKit recognizer (`cancelsTouchesInView = false`)
    /// instead of a SwiftUI gesture: a SwiftUI `simultaneousGesture` competes
    /// with `Form` row selection and breaks Picker/NavigationLink rows,
    /// whereas this recognizer only observes taps and never swallows them.
    func dismissKeyboardOnTap() -> some View {
        self
            .scrollDismissesKeyboard(.immediately)
            .background(KeyboardDismissTapInstaller())
    }
}

/// Invisible helper that installs a keyboard-dismissing tap recognizer on the
/// window while its host view is on screen, and removes it when it leaves.
private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView, UIGestureRecognizerDelegate {
        private var recognizer: UITapGestureRecognizer?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            // Detach from the previous window (screen dismissed / moved).
            if let recognizer {
                recognizer.view?.removeGestureRecognizer(recognizer)
                self.recognizer = nil
            }
            guard let window else { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tap.cancelsTouchesInView = false // observe only — never eat the tap
            tap.delegate = self
            window.addGestureRecognizer(tap)
            recognizer = tap
        }

        @objc private func dismissKeyboard() {
            window?.endEditing(true)
        }

        // Play nice with every other gesture (scrolling, row selection, …).
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        // Don't fire when tapping into a text input — let it take focus.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view: UIView? = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }
    }
}

// MARK: - Emoji text field

/// A text field that opens the emoji keyboard directly when focused.
///
/// UIKit has no public emoji `UIKeyboardType`, but a responder can report the
/// emoji input mode as its preferred one via `textInputMode` — the system
/// then presents the emoji keyboard by default (the user can still switch
/// keyboards with the globe key).
struct EmojiTextField: UIViewRepresentable {
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
