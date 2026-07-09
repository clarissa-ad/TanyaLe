import SwiftUI
import RealityKit
import ARKit
import Combine
import CoreLocation
import UIKit

// MARK: - Main View

struct RelativeMakerARView: View {
    @State private var viewModel       = MakerViewModel()
    @State private var locationManager = LocationManager()

    @State private var isOriginSet     = false
    @State private var showingAddSheet = false
    /// True when the reticle is resting on a detected surface
    @State private var isTracking      = false

    @State private var tempTitle: String                               = ""
    @State private var tempDesc: String                                = ""
    @State private var tempInteractionType: Checkpoint.InteractionType = .none
    @State private var tempQuestion: String                            = ""
    @State private var tempSurveyOptions: [String]                     = []
    @State private var tempEmojiLeft: String                           = ""
    @State private var tempEmojiRight: String                          = ""

    // Shared mutable bridge between SwiftUI and the UIViewRepresentable
    class ARContainer {
        var view: ARView?
        /// Camera-space anchor — always attached to the camera, immune to setWorldOrigin
        var cameraAnchor: AnchorEntity?
        /// Child entity of cameraAnchor that holds the ring visuals, positioned in camera space
        var reticleGroup: Entity?
        var updateSubscription: Combine.Cancellable?
        /// The anchor holding the reticle group
        var worldAnchor: AnchorEntity?
        /// World-space hit position — nil when NOT on a real surface (used by buttons)
        var reticlePosition: SIMD3<Float>?
        /// True when the reticle is resting on a detected surface
        var isOnSurface: Bool = false
        /// Called on the main thread whenever surface tracking state changes
        var onTrackingChanged: ((Bool) -> Void)?
        /// Called on the main thread when user taps the screen
        var onTap: (() -> Void)?
    }
    private let arContainer = ARContainer()

    // MARK: Body

    var body: some View {
        ZStack {
            RelativeMakerARViewContainer(arContainer: arContainer)
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()
                if !isOriginSet {
                    originPanel
                } else {
                    placementPanel
                }
            }
        }
        .onAppear {
            locationManager.requestPermission()
            arContainer.onTrackingChanged = { tracking in
                isTracking = tracking
            }
            arContainer.onTap = { resetReticle() }
        }
        .navigationTitle("Maker (Relative AR)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: NavigationLink(destination: CheckpointListView()) {
            Image(systemName: "list.bullet")
                .font(.title2)
                .foregroundStyle(.blue)
        })
        .sheet(isPresented: $showingAddSheet) { addSheet }
    }

    // MARK: Panels

    private var originPanel: some View {
        VStack(spacing: 15) {
            Text("Stand at the App Clip location. Aim the reticle at it, then tap below.")
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.black.opacity(0.7))
                .foregroundStyle(.white)
                .cornerRadius(10)

            Button(action: setOrigin) {
                Text("Set Origin Here")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isTracking ? Color.blue : Color.gray.opacity(0.5))
                    .foregroundStyle(.white)
                    .cornerRadius(15)
            }
            .disabled(!isTracking)
        }
        .padding(20)
        .padding(.bottom, 20)
    }

    private var placementPanel: some View {
        VStack(spacing: 10) {
            // Always-visible status label
            Label(
                isTracking ? "Surface detected — aim and drop" : "Scanning… tap screen to reset",
                systemImage: isTracking ? "scope" : "hand.tap"
            )
            .font(.footnote)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .foregroundStyle(.white)
            .cornerRadius(20)

            Button(action: { if isTracking { showingAddSheet = true } }) {
                HStack {
                    Image(systemName: "cube.transparent")
                    Text("Drop Checkpoint Here")
                        .fontWeight(.bold)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(isTracking ? Color.purple : Color.gray.opacity(0.5))
                .foregroundStyle(.white)
                .cornerRadius(15)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .disabled(!isTracking)
        }
    }

    private var addSheet: some View {
        NavigationView {
            Form {
                CheckpointFormContent(
                    title: $tempTitle,
                    taskDescription: $tempDesc,
                    interactionType: $tempInteractionType,
                    question: $tempQuestion,
                    surveyOptions: $tempSurveyOptions,
                    emojiLeft: $tempEmojiLeft,
                    emojiRight: $tempEmojiRight
                )
            }
            .navigationTitle("New Checkpoint")
            .navigationBarItems(
                leading: Button("Cancel") { showingAddSheet = false },
                trailing: Button("Save") {
                    if let pos = arContainer.reticlePosition {
                        saveCheckpoint(at: pos)
                    }
                }
                .disabled(tempTitle.isEmpty)
            )
        }
    }

    // MARK: Actions

    /// Tap-to-reset: shows/re-centers the reticle immediately.
    private func resetReticle() {
        arContainer.reticleGroup?.isEnabled = false
        arContainer.isOnSurface = false
    }

    private func setOrigin() {
        guard let arView = arContainer.view,
              let pos    = arContainer.reticlePosition else { return }

        var t = matrix_identity_float4x4
        t.columns.3 = SIMD4<Float>(pos.x, pos.y, pos.z, 1)
        arView.session.setWorldOrigin(relativeTransform: t)
        isOriginSet = true
        
        // Rebuild the anchor in the new coordinate system so our world-space 
        // transforms (hitWorldPos) match 1:1 with the reticle's local space.
        arContainer.worldAnchor?.removeFromParent()
        let newAnchor = AnchorEntity(world: .zero)
        if let group = arContainer.reticleGroup {
            newAnchor.addChild(group)
        }
        arView.scene.addAnchor(newAnchor)
        arContainer.worldAnchor = newAnchor

        let loc = locationManager.userLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: -6.200000, longitude: 106.816666)
        MockDatabaseService.shared.surveyOrigin = loc
    }

    private func saveCheckpoint(at position: SIMD3<Float>) {
        guard let arView = arContainer.view else { return }

        let anchor = AnchorEntity(world: position)
        let boxEntity = Entity()
        boxEntity.components.set(ModelComponent(
            mesh: MeshResource.generateBox(size: 0.15),
            materials: [SimpleMaterial(color: .purple, isMetallic: true)] as [RealityKit.Material]
        ))
        anchor.addChild(boxEntity)
        arView.scene.addAnchor(anchor)

        viewModel.addCheckpointAt(
            transform: position,
            title: tempTitle,
            description: tempDesc,
            interactionType: tempInteractionType,
            question: tempQuestion.trimmingCharacters(in: .whitespaces),
            surveyOptions: tempSurveyOptions.filter { !$0.isEmpty },
            emojiLeft: tempEmojiLeft,
            emojiRight: tempEmojiRight
        )

        tempTitle           = ""
        tempDesc            = ""
        tempInteractionType = .none
        tempQuestion        = ""
        tempSurveyOptions   = []
        tempEmojiLeft       = ""
        tempEmojiRight      = ""
        showingAddSheet     = false
    }
}

// MARK: - ARView UIViewRepresentable

struct RelativeMakerARViewContainer: UIViewRepresentable {
    let arContainer: RelativeMakerARView.ARContainer

    func makeCoordinator() -> Coordinator { Coordinator(arContainer: arContainer) }

    class Coordinator: NSObject {
        let arContainer: RelativeMakerARView.ARContainer
        init(arContainer: RelativeMakerARView.ARContainer) {
            self.arContainer = arContainer
        }
        /// UIKit tap gesture — fires onTap callback on main thread
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            DispatchQueue.main.async { self.arContainer.onTap?() }
        }
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // ── AR Session ────────────────────────────────────────────────────────
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.worldAlignment = .gravityAndHeading
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        arContainer.view = arView

        // ── Coaching overlay: "Move your phone to start" ──────────────────────
        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.goal    = .anyPlane
        coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coaching.frame   = arView.bounds
        arView.addSubview(coaching)

        // ── UIKit tap gesture (reliable; SwiftUI onTapGesture fails on UIViewRepresentable) ──
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false   // don't block SwiftUI button taps
        arView.addGestureRecognizer(tap)

        // ── 3D Reticle: world-space anchor ────────────────────────────────────
        // We use a world anchor, but we manually calculate and overwrite its
        // transform every single frame. This prevents it from being "left behind"
        // when setWorldOrigin is called.
        let worldAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(worldAnchor)

        // Group entity: we position this in camera space every frame
        let reticleGroup = Entity()

        // ── Proper UI Reticle (Broken Ring & Dot) ─────────────────────────────
        let reticlePlane = Entity()
        var reticleMat = UnlitMaterial()
        
        // Generate texture from code and apply it
        if let reticleCGImage = UIImage.generateReticle()?.cgImage,
           let tex = try? TextureResource.generate(from: reticleCGImage, options: .init(semantic: .color)) {
            reticleMat.color = .init(tint: .white, texture: .init(tex))
            // Enable transparency so the black/clear parts of the image are invisible
            reticleMat.blending = .transparent(opacity: .init(floatLiteral: 1.0))
        } else {
            reticleMat.color = .init(tint: .white) // fallback if texture fails
        }
        
        reticlePlane.components.set(ModelComponent(
            mesh: MeshResource.generatePlane(width: 0.22, depth: 0.22),
            materials: [reticleMat]
        ))

        reticleGroup.addChild(reticlePlane)
        reticleGroup.isEnabled = false   // hidden until first surface/fallback position set
        worldAnchor.addChild(reticleGroup)

        arContainer.worldAnchor  = worldAnchor
        arContainer.reticleGroup = reticleGroup

        // ── Per-frame update loop ─────────────────────────────────────────────
        arContainer.updateSubscription = arView.scene.subscribe(
            to: SceneEvents.Update.self
        ) { [weak arContainer] _ in
            guard let container = arContainer,
                  let view      = container.view,
                  let group     = container.reticleGroup,
                  let frame     = view.session.currentFrame else { return }

            let screenCenter = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            let camTransform  = frame.camera.transform
            let camPos        = SIMD3<Float>(camTransform.columns.3.x,
                                             camTransform.columns.3.y,
                                             camTransform.columns.3.z)

            // ── Raycast: prefer confirmed plane, fall back to estimated ───────
            var hitWorldPos:    SIMD3<Float>? = nil
            var hitWorldNormal: SIMD3<Float>? = nil

            for target: ARRaycastQuery.Target in [.existingPlaneGeometry, .estimatedPlane] {
                if let query  = view.makeRaycastQuery(from: screenCenter,
                                                       allowing: target,
                                                       alignment: .any),
                   let result = view.session.raycast(query).first {
                    hitWorldPos    = SIMD3<Float>(result.worldTransform.columns.3.x,
                                                  result.worldTransform.columns.3.y,
                                                  result.worldTransform.columns.3.z)
                    hitWorldNormal = SIMD3<Float>(result.worldTransform.columns.1.x,
                                                  result.worldTransform.columns.1.y,
                                                  result.worldTransform.columns.1.z)
                    break
                }
            }

            // ── Calculate World-Space Transform ───────────────────────────────
            let camForward = normalize(-SIMD3<Float>(camTransform.columns.2.x, camTransform.columns.2.y, camTransform.columns.2.z))
            
            let targetPos:    SIMD3<Float>
            let targetNormal: SIMD3<Float>
            let dist:         Float
            let onSurface:    Bool

            if let wp = hitWorldPos, let wn = hitWorldNormal {
                targetPos    = wp
                targetNormal = wn
                dist         = length(wp - camPos)
                onSurface    = true
            } else {
                // Fallback: 1.5 m straight ahead, flat on the horizontal plane
                targetPos    = camPos + camForward * 1.5
                targetNormal = SIMD3<Float>(0, 1, 0)
                dist         = 1.5
                onSurface    = false
            }

            // ── Orientation: Flat on surface, facing the camera ───────────────
            // We want the reticle's Y axis to align with the surface normal.
            // We want its Z axis (forward) to point away from the camera.
            let forward = normalize(targetPos - camPos)
            // Compute right vector (orthogonal to normal and forward)
            var right = cross(targetNormal, forward)
            if length(right) < 0.001 { right = SIMD3<Float>(1, 0, 0) } // fallback if looking straight down
            right = normalize(right)
            // Compute true forward (orthogonal to right and normal)
            let trueForward = normalize(cross(right, targetNormal))
            
            // Construct rotation matrix (columns: X, Y, Z)
            let rotMatrix = simd_float3x3(right, targetNormal, trueForward)
            let q = simd_quatf(rotMatrix)

            // ── Scale: constant apparent size ─────────────────────────────────
            let scale = max(0.5, min(2.5, dist / 1.5))

            // Apply directly in world space
            group.transform = Transform(
                scale:       SIMD3<Float>(repeating: scale),
                rotation:    q,
                translation: targetPos
            )
            if !group.isEnabled { group.isEnabled = true }

            // World-space position is only valid for button use when on a surface
            container.reticlePosition = onSurface ? hitWorldPos : nil

            // Notify SwiftUI of tracking state changes
            if onSurface != container.isOnSurface {
                container.isOnSurface = onSurface
                DispatchQueue.main.async { container.onTrackingChanged?(onSurface) }
            }
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
        let c = coordinator.arContainer
        c.updateSubscription?.cancel()
        c.updateSubscription = nil
        c.worldAnchor        = nil
        c.reticleGroup       = nil
        c.reticlePosition    = nil
        c.isOnSurface        = false
        c.view               = nil
    }
}

#Preview {
    RelativeMakerARView()
}

// MARK: - Reticle Texture Generator

extension UIImage {
    /// Generates a perfectly crisp broken-ring reticle with a center dot
    static func generateReticle() -> UIImage? {
        let size = CGSize(width: 512, height: 512)
        // scale 1.0 because we are mapping this to a texture
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Transparent background
        context.clear(CGRect(origin: .zero, size: size))
        
        // Setup line style
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(30)
        context.setLineCap(.round)
        
        let center = CGPoint(x: 256, y: 256)
        let radius: CGFloat = 200
        
        // Right arc (from -45 deg to 45 deg)
        context.beginPath()
        context.addArc(center: center, radius: radius, startAngle: -.pi * 0.25, endAngle: .pi * 0.25, clockwise: false)
        context.strokePath()
        
        // Left arc (from 135 deg to 225 deg)
        context.beginPath()
        context.addArc(center: center, radius: radius, startAngle: .pi * 0.75, endAngle: .pi * 1.25, clockwise: false)
        context.strokePath()
        
        // Center dot
        context.setFillColor(UIColor.white.cgColor)
        let dotRadius: CGFloat = 24
        context.fillEllipse(in: CGRect(x: center.x - dotRadius, y: center.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
