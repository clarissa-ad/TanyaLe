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
    @StateObject private var manager = WalkableAspirationManager()
    @StateObject private var locationManager = LocationManager()
    @State private var showSheet = false

    // Insulate the ARView from SwiftUI re-renders (same trick as RelativeUserARView).
    final class ARContainer {
        var view: ARView?
        // Message cards that should keep facing the camera (yaw-only).
        var faceCameraEntities: [Entity] = []
        var updateSubscription: Cancellable?
        // Board controllers kept alive while their cards are in the scene.
        var boardControllers: [any ARSurveyBoard] = []
    }
    private let arContainer = ARContainer()

    var body: some View {
        ZStack {
            WalkableAspirationARContainer(arContainer: arContainer)
                .edgesIgnoringSafeArea(.all)

            // "You are here" marker in the center of the screen.
            Image(systemName: "location.north.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 2)

            VStack {
                // Small HUD showing how many messages exist this session.
                Text("\(manager.aspirations.count) message\(manager.aspirations.count == 1 ? "" : "s") left here")
                    .font(.caption)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.top, 50)

                Spacer()

                // The leave-a-message button. We present the sheet ourselves (instead
                // of using WalkableAspirationButton's built-in sheet) so the submitted
                // text can reach the AR board-dropping logic below.
                Button {
                    showSheet = true
                } label: {
                    Image(systemName: "bubble.and.pencil")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 8)
                }
                .accessibilityLabel("Leave a message here")
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            locationManager.requestPermission()
        }
        .sheet(isPresented: $showSheet) {
            TextFieldBottomSheet { text in
                dropMessageBoard(message: text)
            }
        }
        .navigationTitle("Walkable Aspirations")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Drop a floating message board at the exact spot the user is standing.
    private func dropMessageBoard(message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let arView = arContainer.view,
              let frame = arView.session.currentFrame else { return }

        // Camera transform = where the phone is. columns.3 is its world position.
        let cam = frame.camera.transform
        let camPos = SIMD3<Float>(cam.columns.3.x, cam.columns.3.y, cam.columns.3.z)

        // The user's feet are roughly 1.4m below the phone. Anchor at the ground
        // where they're standing; the card itself floats up from there.
        let standing = SIMD3<Float>(camPos.x, camPos.y - 1.4, camPos.z)

        // 1. Persist the message (in-memory for now, via the manager).
        let coordinate = locationManager.userLocation?.coordinate
        let aspiration = WalkableAspiration(
            message: trimmed,
            latitude: coordinate?.latitude ?? 0,
            longitude: coordinate?.longitude ?? 0,
            relativeX: standing.x,
            relativeY: standing.y,
            relativeZ: standing.z
        )
        manager.add(aspiration)

        // 2. Build the message board and anchor it at the standing spot. Building
        // the card is async (texture upload), so it's added when ready.
        let anchor = AnchorEntity(world: standing)
        arView.scene.addAnchor(anchor)

        Task { @MainActor in
            guard let controller = await MessageBoardController.make(message: trimmed) else { return }
            // Float the card up to roughly chest height above where they stood,
            // and keep it turned toward the camera every frame.
            controller.rootEntity.position = [0, 1.2, 0]
            anchor.addChild(controller.rootEntity)
            arContainer.faceCameraEntities.append(controller.rootEntity)
            arContainer.boardControllers.append(controller)
        }
    }
}

struct WalkableAspirationARContainer: UIViewRepresentable {
    let arContainer: WalkableAspirationView.ARContainer

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.worldAlignment = .gravityAndHeading // Locks Z-axis to True North
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        arContainer.view = arView

        // Rotate each message card toward the camera every frame, yaw-only, so
        // it stays upright and readable from any side (same as the survey boards).
        arContainer.updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak arContainer] _ in
            guard let arContainer, let arView = arContainer.view else { return }
            let cameraPosition = arView.cameraTransform.translation
            for entity in arContainer.faceCameraEntities {
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
