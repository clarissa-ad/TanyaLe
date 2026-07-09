import SwiftUI

@main
struct TanyaLeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// App entry flow: starts on the welcome screen, then pushes into the AR walk
/// experience once the user taps "Continue to Journey".
struct RootView: View {
    @State private var showARWalk = false

    var body: some View {
        SandboxDashboardView()
    }
}

#Preview {
    RootView()
}
