//
//  WalkableAspirationButton.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 05/07/26.
//

import SwiftUI

struct WalkableAspirationButton: View {
    @State private var showSheet: Bool = false
    /// Set when the sheet submits; consumed once the sheet has fully
    /// dismissed so the confirmation popup never fights the sheet animation.
    @State private var confirmationPending: Bool = false
    @State private var showConfirmation: Bool = false

    let systemName: String
    let accessibilityLabel: String
    /// Called with the text the user submitted in the sheet.
    let onSubmit: (String) -> Void

    var body: some View {

        ZStack {
            Button {
                showSheet.toggle()
            } label: {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.blue)
                    .glassEffect()
                    .clipShape(Circle())
            }
            .accessibilityLabel(accessibilityLabel)
            .sheet(isPresented: $showSheet) {
                TextFieldBottomSheet { text in
                    onSubmit(text)
                    // Only confirm messages that actually get dropped —
                    // dropMessage() ignores whitespace-only text.
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        confirmationPending = true
                    }
                }
                .onDisappear {
                    guard confirmationPending else { return }
                    confirmationPending = false
                    // Present the cover without its default slide-up so the
                    // popup fully owns its appear animation.
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { showConfirmation = true }
                }
            }
            .fullScreenCover(isPresented: $showConfirmation) {
                AspirationConfirmationPopup {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { showConfirmation = false }
                }
                .presentationBackground(.clear)
            }
            .glassEffect()
        }
    }
}

#Preview {
    WalkableAspirationButton(systemName: "bubble.and.pencil", accessibilityLabel: "Add messages") { text in
        print("User wrote:", text)
    }
}
