//
//  WalkableAspirationView.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 05/07/26.
//

import SwiftUI
import RealityKit
import ARKit
import Combine

struct WalkableAspirationView: View {
    @State private var manager = WalkableAspirationManager()
    @State private var locationManager = LocationManager()
    @State private var showSheet = false

    // Owns the ARView and everything in the AR scene; insulated from SwiftUI re-renders.
    private let sceneController = WalkableAspirationSceneController()

    var body: some View {
        ZStack {
            WalkableAspirationARContainer(sceneController: sceneController)
                .edgesIgnoringSafeArea(.all)

            // "You are here" marker in the center of the screen.
            Image(systemName: "location.north.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 2)

            VStack {
                // Small HUD showing how many messages exist this session.
                Text("\(manager.aspirations.count) message\(manager.aspirations.count == 1 ? "" : "s") left here")
                    .font(.caption)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                    .padding(.top, 50)

                Spacer()

                // The leave-a-message button. The button owns the sheet; it hands
                // the submitted text back to us so we can drop it as an AR board.
                WalkableAspirationButton(
                    systemName: "bubble.and.pencil",
                    accessibilityLabel: "Leave a message here"
                ) { text in
                    // Scene controller drops the board and hands back the aspiration;
                    // we own persistence, so we save it here.
                    if let aspiration = sceneController.dropMessageBoard(
                        message: text,
                        coordinate: locationManager.userLocation?.coordinate
                    ) {
                        manager.add(aspiration)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            locationManager.requestPermission()
        }
        .navigationTitle("Walkable Aspirations")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WalkableAspirationARContainer: UIViewRepresentable {
    let sceneController: WalkableAspirationSceneController

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.worldAlignment = .gravityAndHeading // Locks Z-axis to True North
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        sceneController.view = arView

        // Rotate each message card toward the camera every frame, yaw-only, so
        // it stays upright and readable from any side (same as the survey boards).
        sceneController.updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak sceneController] _ in
            guard let sceneController, let arView = sceneController.view else { return }
            let cameraPosition = arView.cameraTransform.translation
            for entity in sceneController.faceCameraEntities {
                entity.yawToFace(cameraPosition: cameraPosition)
            }
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

#Preview {
    WalkableAspirationView()
}
