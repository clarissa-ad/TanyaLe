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
    let action: () -> Void

    var body: some View {
        
        ZStack{
            Button {
                action()
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
                    print("User wrote:", text)
                }
            }
            .glassEffect()
        }
    }
}

#Preview {
    WalkableAspirationButton(systemName: "bubble.and.pencil", accessibilityLabel: "Add messages", action: {})
}
