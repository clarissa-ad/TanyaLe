import SwiftUI

@main
struct TanyaLeApp: App {
    var body: some Scene {
        WindowGroup {
            // Setting SandboxDashboardView as the neutral entry point
            // for developers to test individual features before merging into complex flows.
            SandboxDashboardView()
        }
    }
}
