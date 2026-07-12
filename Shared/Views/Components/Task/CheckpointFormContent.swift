import SwiftUI
import UIKit
import AVKit

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
    @Binding var selectedAssetId: String?
    @Binding var showingAssetPicker: Bool
    
    // Tracks whether the extra 2 slots (5 & 6) are visible.
    @State private var showExtraOptions = false
    @State private var newOption: String = ""
    
    // Added state to track when the video sheet is presented
    @State private var showingDemoVideo = false
    
    private var selectedAsset: Asset3D? {
        guard let selectedAssetId else { return nil }
        return MockAssetService.shared.asset(withId: selectedAssetId)
    }
    
    var body: some View {
        Group {
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
            if interactionType != .none {
                Section{
                    // 3. Added the completely styled pill button
                    Button(action: {
                        showingDemoVideo = true
                    }) {
                        Text("Watch Demo Video")
                            .font(.system(size: 16, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.brandPurple)
                    .background(Color.clear)
                    .overlay(
                        Capsule()
                            .stroke(Color.brandPurple, lineWidth: 1.5)
                    )
                    .listRowBackground(Color.clear)
                    .sheet(isPresented: $showingDemoVideo) {
                        DemoVideoPlayerView(isPresented: $showingDemoVideo, interactionType: interactionType)
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
            } else if interactionType == .likedislike {
                Section(header: Text("Like & Dislike"), footer: Text("The citizen sees this 3D item in AR and votes whether they like it.")) {
                    Button {
                        showingAssetPicker = true
                    } label: {
                        HStack {
                            if let selectedAsset {
                                AssetThumbnailImage(asset: selectedAsset, iconSize: 20)
                                    .frame(width: 28, height: 28)
                                Text(selectedAsset.name)
                                    .foregroundStyle(.primary)
                            } else {
                                Text("Select an Item")
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    TextField("Custom Question", text: $question)
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
    
    private func setupMCQSlots() {
        if surveyOptions.count > 4 {
            showExtraOptions = true
            ensureCapacity(6)
        } else {
            ensureCapacity(4)
        }
    }
}

// MARK: - Video Player View
// 5. This handles playing the correct MP4 file safely

struct DemoVideoPlayerView: View {
    // 1. Use a binding instead of the environment dismiss
    @Binding var isPresented: Bool
    let interactionType: Checkpoint.InteractionType
    
    @State private var player: AVPlayer?
    @State private var videoNotFound = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let player {
                    VideoPlayer(player: player)
                        .onAppear { player.play() }
                        .onDisappear { player.pause() }
                } else if videoNotFound {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 40))
                        Text("Demo video not found.")
                            .font(.headline)
                        Text("Missing file: \(videoFileName(for: interactionType)).mp4")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.gray)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("\(interactionType.rawValue) Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                                isPresented = false
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 36, height: 36)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
//                    .disabled(videoNotFound)
                }
            }
            .onAppear { setupPlayer() }
            // Prevents swipe-to-dismiss if video is missing
//            .interactiveDismissDisabled(videoNotFound)
        }
    }
    
    private func setupPlayer() {
        let fileName = videoFileName(for: interactionType)
        if let url = Bundle.main.url(forResource: fileName, withExtension: "mp4") {
            player = AVPlayer(url: url)
        } else {
            videoNotFound = true
        }
    }
    
    private func videoFileName(for type: Checkpoint.InteractionType) -> String {
        switch type {
        case .mcq: return "demo_mcq"
        case .photobooth: return "demo_photobooth"
        case .emojiSlider: return "demo_emoji"
        case .likedislike: return "demo_likedislike"
        default: return "demo_default"
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
