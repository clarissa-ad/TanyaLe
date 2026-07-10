import SwiftUI

/// Fills the bottom half of the screen with scattered copies of the chosen
/// emoji after an emoji slider is submitted. Each emoji is an independent
/// bubble: it springs in with a bouncy overshoot, floats for a moment, then
/// pops away (a quick scale-up while fading out). The presenting view removes
/// the overlay after a few seconds. Touches pass through, so the AR view
/// stays interactive.
struct EmojiCelebrationView: View {
    let emoji: String

    fileprivate struct EmojiSpot: Identifiable {
        let id = UUID()
        /// Horizontal position, relative 0...1 across the full width.
        let x: CGFloat
        /// Vertical position, relative 0...1 within the bottom half.
        let y: CGFloat
        let size: CGFloat
        let rotation: Angle
        /// Staggered delay before the bubble springs in.
        let appearDelay: Double
        /// How long the bubble stays on screen before popping.
        let lifetime: Double
    }

    @State private var spots: [EmojiSpot] = []

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(spots) { spot in
                    EmojiBubble(emoji: emoji, spot: spot)
                        .position(
                            x: spot.x * proxy.size.width,
                            y: proxy.size.height / 2 + spot.y * proxy.size.height / 2
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
                    appearDelay: .random(in: 0...0.35),
                    lifetime: .random(in: 1.0...2.5)
                )
            }
        }
    }
}

/// One emoji living its bubble life: spring in → float → pop.
private struct EmojiBubble: View {
    let emoji: String
    let spot: EmojiCelebrationView.EmojiSpot

    private enum Phase {
        case hidden
        case shown
        case popped
    }

    @State private var phase: Phase = .hidden

    private var scale: CGFloat {
        switch phase {
        case .hidden: return 0.2
        case .shown: return 1
        case .popped: return 1.5 // bubbles expand as they burst
        }
    }

    private var opacity: Double {
        phase == .shown ? 1 : 0
    }

    var body: some View {
        Text(emoji)
            .font(.system(size: spot.size))
            .rotationEffect(spot.rotation)
            .scaleEffect(scale)
            .opacity(opacity)
            .task {
                try? await Task.sleep(for: .seconds(spot.appearDelay))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                    phase = .shown
                }
                try? await Task.sleep(for: .seconds(spot.lifetime))
                withAnimation(.easeOut(duration: 0.3)) {
                    phase = .popped
                }
            }
    }
}

#Preview {
    EmojiCelebrationView(emoji: "😅")
}
