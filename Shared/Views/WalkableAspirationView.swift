//
//  WalkableAspirationDummy.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 05/07/26.
//

/// ⚠️ TEMPORARY DEV FILE ⚠️

import SwiftUI


struct WalkableAspirationView: View {
    var body: some View {
        Text("Hello, World!")
        WalkableAspirationButton(
            systemName: "bubble.and.pencil",
            accessibilityLabel: "Leave a message"
        ) {}
    }
}

#Preview {
    WalkableAspirationView()
}
