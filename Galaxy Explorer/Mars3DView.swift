import SwiftUI
import SceneKit
import UIKit

/// A reusable Mars view. The tap callback receives texture UV coordinates (0...1).
/// Add an equirectangular Mars image to Assets.xcassets as "marsTexture".
struct Mars3DView: UIViewRepresentable {
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

        let components = MarsSceneFactory.makeScene()
        view.scene = components.scene
        view.pointOfView = components.cameraNode

        let coordinator = context.coordinator
        coordinator.scnView = view
        coordinator.cameraNode = components.cameraNode
        coordinator.marsNode = components.marsNode

        // Custom gestures keep rotation and zoom within the intended limits.
        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = coordinator
        view.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinch.delegate = coordinator
        view.addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = coordinator
        // A drag or pinch must not also trigger the surface callback.
        tap.require(toFail: pan)
        tap.require(toFail: pinch)
        view.addGestureRecognizer(tap)

        _ = view.prepare(components.scene, shouldAbortBlock: nil)
        coordinator.startImmersion()
        view.setNeedsDisplay()
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // SwiftUI may replace the callback without recreating the SceneKit view.
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        // Stop frame callbacks when SwiftUI removes this view.
        coordinator.stopImmersion()
        coordinator.stopInertia()
        uiView.scene = nil
    }

}
