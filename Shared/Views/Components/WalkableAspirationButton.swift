//
//  WalkableAspirationButton.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 05/07/26.
//

import SwiftUI

struct WalkableAspirationButton: View {
    @State private var showSheet: Bool = false

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
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.blue)
                    .glassEffect()
                    .clipShape(Circle())
            }
            .accessibilityLabel(accessibilityLabel)
            .sheet(isPresented: $showSheet) {
                TextFieldBottomSheet { text in
                    onSubmit(text)
                }
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
