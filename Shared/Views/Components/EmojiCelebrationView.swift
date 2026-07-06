import SwiftUI

/// Fills the bottom half of the screen with scattered copies of the chosen
/// emoji after an emoji slider is submitted. Emojis pop in with a staggered
/// spring; the presenting view is responsible for removing the overlay after
/// a few seconds. Touches pass through, so the AR view stays interactive.
struct EmojiCelebrationView: View {
    let emoji: String

    private struct EmojiSpot: Identifiable {
        let id = UUID()
        /// Horizontal position, relative 0...1 across the full width.
        let x: CGFloat
        /// Vertical position, relative 0...1 within the bottom half.
        let y: CGFloat
        let size: CGFloat
        let rotation: Angle
        let delay: Double
    }

    @State private var spots: [EmojiSpot] = []
    @State private var isVisible = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(spots) { spot in
                    Text(emoji)
                        .font(.system(size: spot.size))
                        .rotationEffect(spot.rotation)
                        .position(
                            x: spot.x * proxy.size.width,
                            y: proxy.size.height / 2 + spot.y * proxy.size.height / 2
                        )
                        .opacity(isVisible ? 1 : 0)
                        .scaleEffect(isVisible ? 1 : 0.3)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.6).delay(spot.delay),
                            value: isVisible
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            spots = (0..<36).map { _ in
                EmojiSpot(
                    x: .random(in: 0.03...0.97),
                    y: .random(in: 0.03...0.95),
                    size: .random(in: 26...58),
                    rotation: .degrees(.random(in: -25...25)),
                    delay: .random(in: 0...0.35)
                )
            }
            isVisible = true
        }
    }
}

#Preview {
    EmojiCelebrationView(emoji: "😅")
}
