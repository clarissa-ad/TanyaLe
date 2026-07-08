import SwiftUI

/// The app's standard full-width call-to-action button — bold white text on
/// a solid color background with the app's 15pt corner radius. Matches the
/// existing primary-action buttons ("Scan App Clip", "Drop Checkpoint Here"
/// in RelativeMakerARView) so new CTAs stay visually consistent instead of
/// each screen redefining its own button look.
struct PrimaryActionButton: View {
    let title: String
    var systemImage: String? = nil
    var color: Color = .purple
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundStyle(.white)
            .cornerRadius(15)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

#Preview {
    VStack(spacing: 12) {
        PrimaryActionButton(title: "Use this Item") {}
        PrimaryActionButton(title: "Drop Checkpoint Here", systemImage: "cube.transparent") {}
        PrimaryActionButton(title: "Disabled", isDisabled: true) {}
    }
    .padding()
}
