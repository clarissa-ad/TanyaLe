import SwiftUI

struct SandboxDashboardView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("AR Prototypes")) {
                    NavigationLink(destination: ARPlacementPrototypeView()) {
                        Label("Test AR Checkpoint Placement", systemImage: "arkit")
                    }
                }
                
                Section(header: Text("Data Prototypes")) {
                    Text("Test CloudKit Auth (Coming Soon)")
                        .foregroundColor(.secondary)
                }
                Section(header: Text("Citizen Prototypes")) {
                    NavigationLink(destination: UserMinimapView()) {
                        Label("Test User Minimap", systemImage: "map.circle")
                    }
                }
                
                Section(header: Text("UI Prototypes")) {
                    Text("Test 3D Asset Likability UI (Coming Soon)")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Developer Sandbox")
        }
    }
}

#Preview {
    SandboxDashboardView()
}
