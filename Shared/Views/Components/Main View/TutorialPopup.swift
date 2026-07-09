//
//  TutorialPopup.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 07/07/26.
//
import SwiftUI

/// A frosted-glass tutorial card shown over the AR walk screen on first load.
/// It explains the three things the user can do here and dismisses when the
/// user taps the primary button.
///
/// The card owns no visibility state itself — the host decides when to show it
/// and reacts to `onDismiss` — so it stays a dumb, reusable overlay.
struct TutorialPopup: View {
    var title: String = "Explore this space!"
    var buttonTitle: String = "Start Exploring"
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
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Self.titleGradient)

            VStack(alignment: .leading, spacing: 24) {
                FeatureRow(
                    icon: .mascot,
                    heading: "Find Lele",
                    detail: "Follow the arrow to meet Lele and unlock quick missions about this environment"
                )
                FeatureRow(
                    icon: .glyph("map", foreground: Self.blue, background: .thinMaterial),
                    heading: "Use the map",
                    detail: "Check nearby missions around you, then walk to the spot to begin"
                )
                FeatureRow(
                    icon: .glyph("bubble.and.pencil", foreground: .white, background: Color(Self.blue)),
                    heading: "Leave your thoughts",
                    detail: "Drop a message in this exact location so the space owner can understand what you hope for"
                )
            }

            Button(action: onDismiss) {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Self.buttonGradient)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }

    // MARK: - Styling

    private static let blue = Color(red: 0.21, green: 0.52, blue: 1.0)          // #3684FF

    private static let titleGradient = LinearGradient(
        colors: [
            Color(red: 0.41, green: 0.0, blue: 0.60),                            // #680099
            Color(red: 0.68, green: 0.0, blue: 1.0)                              // #AD00FF
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    private static let buttonGradient = LinearGradient(
        colors: [
            Color(red: 0.78, green: 0.11, blue: 0.90),
            Color(red: 0.55, green: 0.13, blue: 0.95)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

/// A single icon + heading + detail line inside the tutorial card.
private struct FeatureRow: View {
    enum Icon {
        case mascot
        case symbol(String, foreground: Color, background: AnyShapeStyle)

        static func glyph(_ name: String, foreground: Color, background: some ShapeStyle) -> Icon {
            .symbol(name, foreground: foreground, background: AnyShapeStyle(background))
        }
    }

    let icon: Icon
    let heading: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 17) {
            iconView
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                Text(heading)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.body)
                    .foregroundStyle(Color(red: 0.21, green: 0.21, blue: 0.21)) // #363636
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .mascot:
            Image("lele_mascot")
                .resizable()
                .scaledToFit()
                .padding(.top, 2)
        case let .symbol(name, foreground, background):
            Image(systemName: name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 48, height: 48)
                .background(background, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        TutorialPopup {}
    }
}
