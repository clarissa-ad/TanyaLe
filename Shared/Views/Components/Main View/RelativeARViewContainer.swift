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
        /// Debounce taps to prevent rapid-fire events
        private var lastTapTime: Date = .distantPast

        init(arContainer: RelativeUserARView.ARContainer) {
            self.arContainer = arContainer
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            // Debounce: ignore taps within 200ms of the last one
            let now = Date()
            guard now.timeIntervalSince(lastTapTime) > 0.2 else { return }
            lastTapTime = now
            
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
        
        // Optimize render options for better performance
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]

        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapRecognizer)

        let panRecognizer = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panRecognizer.maximumNumberOfTouches = 1
        arView.addGestureRecognizer(panRecognizer)
        
        let config = ARWorldTrackingConfiguration()
        // Only detect horizontal planes if you don't need vertical (walls)
        config.planeDetection = [.horizontal]
        config.worldAlignment = .gravityAndHeading
        
        // Reduce frame rate for better performance (default is 60fps)
        config.frameSemantics = []
        
        // Optional: disable auto-focus if not needed for better performance
        // config.isAutoFocusEnabled = false
        
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        arContainer.view = arView

        // Handle AR session interruptions (phone calls, notifications, etc.)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            arView.session.pause()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal]
            config.worldAlignment = .gravityAndHeading
            config.frameSemantics = []
            arView.session.run(config, options: [])
        }

        // Rotate the question boards toward the camera every frame, yaw-only,
        // so they stand upright like beacons and stay readable from any side.
        // Throttle to ~20fps instead of 60fps to reduce CPU load.
        var frameCount = 0
        arContainer.updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak arContainer] _ in
            frameCount += 1
            guard frameCount % 3 == 0 else { return } // Only update every 3rd frame
            
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
