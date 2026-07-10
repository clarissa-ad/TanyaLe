//
//  StartPointConfirmationView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 10/07/26.
//

import SwiftUI

/// Third step of the creation flow (pushed automatically once the start point
/// is saved): a confirmation moment before continuing to checkpoint placement.
struct StartPointConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    let journey: Journey
    /// Forwarded to the AR placement flow; ends the whole creation flow.
    var onFlowFinished: () -> Void = {}

    @State private var showARPlacement = false

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer()

                // Confirmation badge + copy
                VStack(spacing: 16) {
                    Image(systemName: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 120)
                        .background(Color.brandPurple, in: Circle())
                        .padding(.bottom, 8)

                    Text("Start point set!")
                        .font(.title.bold())

                    Text("You can continue to make the questions for your respondents to see. Make it as interesting as possible!")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Button {
                    showARPlacement = true
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.brandPurple, in: Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showARPlacement) {
            JourneyARPlacementView(journey: journey, onFlowFinished: onFlowFinished)
        }
    }

    // MARK: - Header (back button + step dots)

    private var header: some View {
        ZStack {
            // Step 3 of 4 in the creation flow.
            HStack(spacing: 12) {
                ForEach(0..<4) { step in
                    Circle()
                        .fill(step < 3 ? Color.brandPurple : Color(.systemGray4))
                        .frame(width: 10, height: 10)
                }
            }

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 48, height: 48)
                        .background(Color.white, in: Circle())
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                // Keep the chevron black instead of the app's accent tint.
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

#Preview {
    NavigationStack {
        StartPointConfirmationView(journey: Journey(name: "Test Journey"))
    }
}
