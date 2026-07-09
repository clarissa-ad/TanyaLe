import SwiftUI

struct SandboxDashboardView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Maker Prototypes")) {
                    NavigationLink(destination: MakerMapView()) {
                        Label("Test Checkpoint Map (2D)", systemImage: "map")
                    }
                    NavigationLink(destination: RelativeMakerARView()) {
                        Label("Test Relative Maker AR", systemImage: "arkit")
                    }
                }
                
                Section(header: Text("Citizen Prototypes")) {
                    NavigationLink(destination: UserMinimapView()) {
                        Label("Test User Minimap (2D)", systemImage: "map.circle")
                    }
                    NavigationLink(destination: RelativeUserARView()) {
                        Label("Test Relative Citizen AR", systemImage: "arkit")
                    }
                    NavigationLink(destination: WalkableAspirationView()) {
                        Label("Walkable Aspiration View", systemImage: "ellipsis.bubble")
                    }
                    NavigationLink(destination: ARWalkView()) {
                        Label("AR Walk View", systemImage: "arkit")
                    }
                }
                
                Section(header: Text("UI Prototypes")) {
                    NavigationLink(destination: WelcomeView()){
                        Label("Main Flow Citizen", systemImage: "hand.thumbsup")
                    }
                    Text("Test 3D Asset Likability UI (Coming Soon)")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Developer Sandbox")
        }
    }
}

#Preview {
    SandboxDashboardView()
}
