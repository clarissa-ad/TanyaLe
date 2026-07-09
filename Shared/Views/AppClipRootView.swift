//
//  AppClipRootView.swift
//  TanyaLe
//
//  The App Clip's entry flow. Lives in Shared/ and is a member of both the
//  main app and the App Clip targets, so it can be previewed from the main
//  `TanyaLe` scheme (App Clip targets can't host SwiftUI Previews) while still
//  being the screen the App Clip actually launches into.
//
//  Mirrors the main app's `RootView`: starts on `WelcomeView`, then pushes into
//  `ARWalkView` once the user taps "Continue to Journey".
//
import SwiftUI

struct AppClipRootView: View {
    @State private var showARWalk = false

    var body: some View {
        NavigationStack {
            WelcomeView {
                showARWalk = true
            }
            .navigationDestination(isPresented: $showARWalk) {
                ARWalkView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

#Preview {
    AppClipRootView()
}
