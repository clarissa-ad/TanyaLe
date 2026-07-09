//
//  TutorialPopup.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 07/07/26.
//
import SwiftUI

/// A frosted-glass tutorial card shown over the AR walk screen on first load.
/// It explains the mission and dismisses when the user taps the primary button.
///
/// The card owns no visibility state itself — the host decides when to show it
/// and reacts to `onDismiss` — so it stays a dumb, reusable overlay.
struct TutorialPopup: View {
    var title: String = "Explore this space and find Lele!"
    var message: String = "He'll give you quick missions to help you notice, reflect, and share your thoughts about this environment"
    var buttonTitle: String = "Find Lele"
    /// Called when the user taps the primary button.
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            card
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.78, green: 0.11, blue: 0.90),
                                Color(red: 0.55, green: 0.13, blue: 0.95)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        TutorialPopup {}
    }
}
