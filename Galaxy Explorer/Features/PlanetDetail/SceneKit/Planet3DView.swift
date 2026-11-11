import SceneKit
import SwiftUI
import UIKit

/// The same offline scene and gesture handling can display any configured planet.
/// The tap callback receives texture UV coordinates (0...1).
struct Planet3DView: UIViewRepresentable {
    var planet: Planet = .mars
    var cardContents: [PlanetCardContent] = []
    var hapticsEnabled = true
    var isInteractionEnabled = true
    var request: PlanetViewRequest? = nil
    var onCardSelected: ((PlanetInformation) -> Void)? = nil
    var onSurfaceTapped: ((CGPoint) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = false
        view.isPlaying = false

        let components = PlanetSceneFactory.makeScene(for: planet)
        view.accessibilityLabel = planet.name
        view.scene = components.scene
        view.pointOfView = components.cameraNode

        let coordinator = context.coordinator
        coordinator.scnView = view
        coordinator.cameraNode = components.cameraNode
        coordinator.planetNode = components.planetNode

        // Custom gestures keep rotation and zoom within the intended limits.
        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = coordinator
        view.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(
            target: coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinch.delegate = coordinator
        view.addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = coordinator
        // A drag or pinch must not also trigger the surface callback.
        tap.require(toFail: pan)
        tap.require(toFail: pinch)
        view.addGestureRecognizer(tap)

        coordinator.startImmersion()
        coordinator.updateContent(cardContents)
        view.setNeedsDisplay()
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // SwiftUI may replace the callback without recreating the SceneKit view.
        let coordinator = context.coordinator
        let wasEnabled = coordinator.parent.isInteractionEnabled
        coordinator.parent = self
        coordinator.updateContent(cardContents)
        if !hapticsEnabled { coordinator.stopHaptics() }
        if wasEnabled != isInteractionEnabled {
            if isInteractionEnabled { coordinator.startImmersion() } else { coordinator.stopImmersion() }
        }
        if let request { coordinator.apply(request) }
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        // Stop frame callbacks when SwiftUI removes this view.
        coordinator.stopImmersion()
        coordinator.stopInertia()
        uiView.scene = nil
    }
}
