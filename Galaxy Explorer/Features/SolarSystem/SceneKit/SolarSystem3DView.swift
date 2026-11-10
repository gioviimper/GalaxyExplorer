import SceneKit
import SwiftUI
import UIKit
import simd

private final class SolarSystemSceneView: SCNView {
    var onLayout: (() -> Void)?
    private var previousBounds = CGRect.zero
    private var previousInsets = UIEdgeInsets.zero
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds != previousBounds || safeAreaInsets != previousInsets else { return }
        previousBounds = bounds
        previousInsets = safeAreaInsets
        onLayout?()
    }
}

// SceneKit renders the illustration; native buttons expose the same selection to assistive input.
struct SolarSystem3DView: UIViewRepresentable {
    var isActive: Bool
    var hapticsEnabled: Bool
    var request: PlanetViewRequest?
    var onSelect: (Planet) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SCNView {
        let view = SolarSystemSceneView()
        view.backgroundColor = .black
        view.overrideUserInterfaceStyle = .dark
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 30
        let components = SolarSystemSceneFactory.makeScene()
        view.scene = components.scene
        view.pointOfView = components.camera
        let coordinator = context.coordinator
        coordinator.view = view
        coordinator.components = components
        view.onLayout = { [weak coordinator] in coordinator?.layout() }
        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = coordinator
        let pinch = UIPinchGestureRecognizer(target: coordinator, action: #selector(Coordinator.pinch(_:)))
        pinch.delegate = coordinator
        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.tap(_:)))
        tap.delegate = coordinator
        tap.require(toFail: pan)
        tap.require(toFail: pinch)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(tap)
        coordinator.installLabels()
        coordinator.observeLifecycle()
        coordinator.refreshActivity()
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refreshActivity()
        if let request { context.coordinator.apply(request) }
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.stop()
        uiView.scene = nil
    }
}
