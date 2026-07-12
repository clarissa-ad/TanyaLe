//
//  AspirationConfirmationPopup.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 12/07/26.
//
import SwiftUI

/// "Message sent!" confirmation card shown right after an aspiration is
/// dropped (Figma node 2171-2621). Animates itself in, stays on screen for
/// `displayDuration`, animates itself out, then calls `onFinished` so the
/// presenter can tear it down.
struct AspirationConfirmationPopup: View {
    /// X — how long the popup stays fully visible before it dismisses itself.
    var displayDuration: TimeInterval = 3

    /// Called once the disappear animation has finished.
    var onFinished: () -> Void = {}

    @State private var isVisible = false
    @State private var bounceCheckmark = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient.brandPurpleButton(
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)

                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: bounceCheckmark)
            }
            .padding(.bottom, 6)

            Text("Message sent!")
                .font(.headline)

            Text("Take a few steps back to view your message")
                .font(.body)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: 300)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .scaleEffect(isVisible ? 1 : 0.85)
        .opacity(isVisible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sensoryFeedback(.success, trigger: isVisible) { _, shown in shown }
        .task {
            // Appear.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
            // Let the card settle before the checkmark plays its bounce.
            try? await Task.sleep(for: .seconds(0.3))
            bounceCheckmark = true

            try? await Task.sleep(for: .seconds(displayDuration))

            // Disappear.
            withAnimation(.easeIn(duration: 0.25)) {
                isVisible = false
            }
            try? await Task.sleep(for: .seconds(0.25))
            onFinished()
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        AspirationConfirmationPopup()
    }
}
