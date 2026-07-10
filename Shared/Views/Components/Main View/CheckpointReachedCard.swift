//
//  CheckpointReachedCard.swift
//  TanyaLe
//
//  The bottom overlay shown in `ARWalkView` once the citizen is close enough to
//  a checkpoint to interact with it. It renders as a purple gradient that fades
//  up from the bottom edge, with centered white content whose icon, title, and
//  body all react to whether the interaction has been answered yet:
//
//  - Not answered → icon prompts the interaction, title is "Checkpoint
//    Reached", body is the maker's instruction.
//  - Answered     → icon is a success checkmark, title is the question, body is
//    the citizen's answer.
//
//  The view is intentionally pure: it takes a `Checkpoint` and an optional
//  answer so it stays previewable and free of any AR/database dependencies.
//
import SwiftUI

struct CheckpointReachedCard: View {
    let checkpoint: Checkpoint
    /// The citizen's answer for this checkpoint, or `nil` if not answered yet.
    let answer: String?

    private var isAnswered: Bool { answer != nil }

    /// SF Symbol driven by the answered state, then the interaction type.
    private var systemImage: String {
        if isAnswered { return "checkmark.circle.fill" }
        switch checkpoint.interactionType {
        case .mcq:         return "hand.tap"
        case .emojiSlider: return "hand.draw"
        case .photobooth:  return "camera"
        case .likedislike: return "hand.thumbsup"
        case .none:        return "hand.tap"
        }
    }

    /// "Checkpoint Reached" until answered, then the question being asked.
    private var title: String {
        if isAnswered, !checkpoint.question.isEmpty {
            return checkpoint.question
        }
        return "Checkpoint Reached"
    }

    /// The maker's instruction until answered, then the citizen's answer.
    private var message: String {
        if let answer { return answer }
        return checkpoint.taskDescription
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .medium))
                .symbolRenderingMode(.hierarchical)

            Text(title)
                .font(.title2.bold())

            Text(message)
                .font(.body)
                .opacity(0.9)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 72)
        .padding(.bottom, 32)
        .background(
            LinearGradient(
                colors: [.clear, .brandPurple.opacity(0.85), .brandPurple],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea(edges: .bottom)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .onAppear {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

private struct CheckpointReachedCardPreview: View {
    let answer: String?
    var body: some View {
        ZStack {
            LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack {
                Spacer()
                CheckpointReachedCard(
                    checkpoint: Checkpoint(
                        title: "Trash Can Checkpoint",
                        taskDescription: "Tap an option on the floating card, then hit Submit",
                        interactionType: .mcq,
                        question: "How is the trash can situation here?",
                        surveyOptions: ["Looks good", "Needs replacement", "Overflowing"],
                        latitude: 0, longitude: 0,
                        relativeX: 0, relativeY: 0, relativeZ: 0
                    ),
                    answer: answer
                )
            }
        }
    }
}

#Preview("Not answered") { CheckpointReachedCardPreview(answer: nil) }
#Preview("Answered") { CheckpointReachedCardPreview(answer: "Needs replacement") }
