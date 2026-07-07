//
//  RelativeUserARContainer.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 07/07/26.
//
import SwiftUI
import ARKit
import RealityKit

struct RelativeARViewContainer: UIViewRepresentable {
    let arContainer: RelativeUserARView.ARContainer

    func makeCoordinator() -> Coordinator {
        Coordinator(arContainer: arContainer)
    }

    /// Routes taps and drags on the AR view to the interactive survey cards.
    @MainActor
    class Coordinator: NSObject {
        let arContainer: RelativeUserARView.ARContainer
        /// The board currently being dragged (e.g. an emoji slider grab).
        private weak var draggedBoard: (any ARSurveyBoard)?

        init(arContainer: RelativeUserARView.ARContainer) {
            self.arContainer = arContainer
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = arContainer.view else { return }
            let point = recognizer.location(in: arView)
            // Collision-cast so we know both the entity and where on it the
            // tap landed (the slider track needs the position).
            guard let hit = arView.hitTest(point).first else { return }

            let cameraPosition = arView.cameraTransform.translation
            for controller in arContainer.boardControllers {
                if controller.handleTap(on: hit.entity, at: hit.position, cameraPosition: cameraPosition) {
                    return
                }
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let arView = arContainer.view else { return }
            let point = recognizer.location(in: arView)

            switch recognizer.state {
            case .began:
                guard let hit = arView.hitTest(point).first else { return }
                let cameraPosition = arView.cameraTransform.translation
                for controller in arContainer.boardControllers {
                    if controller.beginDrag(on: hit.entity, cameraPosition: cameraPosition) {
                        draggedBoard = controller
                        return
                    }
                }
            case .changed:
                guard let draggedBoard,
                      let ray = arView.ray(through: point) else { return }
                draggedBoard.updateDrag(rayOrigin: ray.origin, rayDirection: ray.direction)
            case .ended, .cancelled, .failed:
                draggedBoard?.endDrag()
                draggedBoard = nil
            default:
                break
            }
        }
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapRecognizer)

        let panRecognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panRecognizer.maximumNumberOfTouches = 1
        arView.addGestureRecognizer(panRecognizer)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.worldAlignment = .gravityAndHeading // Locks Z-axis to True North
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        arContainer.view = arView

        // Rotate the question boards toward the camera every frame, yaw-only,
        // so they stand upright like beacons and stay readable from any side.
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
