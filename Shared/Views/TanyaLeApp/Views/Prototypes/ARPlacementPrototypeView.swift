import SwiftUI
import RealityKit

struct ARPlacementPrototypeView: View {
    var body: some View {
        ZStack {
            ARViewContainer()
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                Text("AR Sandbox (No logic yet)")
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                    .padding(.bottom, 40)
            }
        }
        .navigationTitle("AR Placement")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Neutral AR setup. No tracking configs or anchors added yet.
        // Architect B will implement this later.
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

#Preview {
    ARPlacementPrototypeView()
}
