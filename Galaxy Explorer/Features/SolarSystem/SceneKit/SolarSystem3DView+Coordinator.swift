import SceneKit
import UIKit
import simd

// Owns overview navigation, labels and inertial rotation.
extension SolarSystem3DView {
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: SolarSystem3DView
        weak var view: SCNView?
        var components: SolarSystemSceneFactory.Components?
        private var labels: [UIButton] = []
        private var labelSizes: [Int: CGSize] = [:]
        private var displayLink: CADisplayLink?
        private var zoom: Float = 1
        private var yaw: Float = 0
        private var pitch: Float = 0
        private var lastRequest: UUID?
        private var angularVelocity = SIMD2<Float>.zero
        private var previousFrame: CFTimeInterval?
        private let feedback = UIImpactFeedbackGenerator(style: .rigid)
        private var lastFeedback: CFTimeInterval = 0
        private var fingerTravel: CGFloat = 0

        init(_ parent: SolarSystem3DView) {
            self.parent = parent
            self.lastRequest = parent.request?.id
        }

        deinit { stop() }

        func installLabels() {
            guard let view else { return }
            for (index, planet) in Planet.all.enumerated() {
                let button = UIButton(type: .system)
                var config = UIButton.Configuration.plain()
                config.title = planet.name
                config.baseForegroundColor = .label
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
                    attributes in
                    var result = attributes
                    result.font = UIFont.preferredFont(forTextStyle: .caption1)
                    return result
                }
                button.configuration = config
                button.tag = index
                button.accessibilityLabel = planet.name
                button.accessibilityHint = "Opens details"
                button.accessibilityIdentifier = "solar-system-\(planet.id)"
                button.addTarget(self, action: #selector(selectLabel(_:)), for: .touchUpInside)
                view.addSubview(button)
                labels.append(button)
            }
        }

        func observeLifecycle() {
            let center = NotificationCenter.default
            for name in [
                UIApplication.didBecomeActiveNotification, UIApplication.willResignActiveNotification,
                UIAccessibility.reduceMotionStatusDidChangeNotification,
                UIAccessibility.voiceOverStatusDidChangeNotification,
            ] {
                center.addObserver(self, selector: #selector(activityChanged(_:)), name: name, object: nil)
            }
            center.addObserver(
                self, selector: #selector(textSizeChanged),
                name: UIContentSizeCategory.didChangeNotification, object: nil)
        }

        @objc private func activityChanged(_ notification: Notification) {
            refreshActivity(forcePause: notification.name == UIApplication.willResignActiveNotification)
        }

        @objc private func textSizeChanged() {
            labelSizes.removeAll()
            labels.forEach { $0.setNeedsUpdateConfiguration() }
            layoutLabels()
        }

        func refreshActivity(forcePause: Bool = false) {
            let animate =
                parent.isActive && !forcePause && UIApplication.shared.applicationState == .active
                && !UIAccessibility.isReduceMotionEnabled && !UIAccessibility.isVoiceOverRunning
            components?.system.isPaused = !animate
            view?.isPlaying = animate
            view?.rendersContinuously = animate
            if animate, displayLink == nil {
                let link = CADisplayLink(target: FrameProxy(self), selector: #selector(FrameProxy.tick(_:)))
                link.preferredFramesPerSecond = 30
                link.add(to: .main, forMode: .common)
                displayLink = link
            } else if !animate {
                displayLink?.invalidate()
                displayLink = nil
                angularVelocity = .zero
                previousFrame = nil
            }
            layout()
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            components?.system.isPaused = true
            view?.isPlaying = false
            view?.rendersContinuously = false
            NotificationCenter.default.removeObserver(self)
        }

        func layout() {
            guard let view, let camera = components?.camera, view.bounds.width > 0, view.bounds.height > 0
            else { return }
            // Fit the full model to the narrower field of view in portrait or landscape.
            let aspect = Float(view.bounds.width / view.bounds.height)
            let halfAngle = atan(tan(Float.pi * 22 / 180) * min(1, aspect))
            let distance = max(8, 22 / sin(halfAngle) * zoom)
            camera.position = SCNVector3(0, distance * 0.72, distance * 0.694)
            camera.look(at: SCNVector3Zero)
            layoutLabels()
            view.setNeedsDisplay()
        }

        func layoutLabels() {
            guard let view, let components else { return }
            var occupied: [CGRect] = []
            for (index, planet) in Planet.all.enumerated() {
                guard labels.indices.contains(index), let node = components.bodies[planet.id] else {
                    continue
                }
                let button = labels[index]
                // Presentation coordinates follow SceneKit's orbit animation, including pauses.
                let projected = view.projectPoint(node.presentation.worldPosition)
                let point = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                let size: CGSize
                if let cached = labelSizes[index] {
                    size = cached
                } else {
                    size = button.sizeThatFits(CGSize(width: 220, height: 200))
                    labelSizes[index] = size
                }
                let width = min(view.bounds.width, max(44, size.width))
                let height = max(44, size.height)
                let frame = CGRect(
                    x: min(max(0, point.x - width / 2), view.bounds.width - width),
                    y: point.y + 6, width: width, height: height)
                let visible =
                    projected.z > 0 && projected.z < 1 && view.bounds.contains(frame)
                    && !occupied.contains { $0.intersects(frame.insetBy(dx: -4, dy: -2)) }
                if button.isHidden == visible { button.isHidden = !visible }
                if button.frame != frame { button.frame = frame }
                if visible { occupied.append(frame) }
            }
        }

        @objc private func selectLabel(_ sender: UIButton) {
            guard Planet.all.indices.contains(sender.tag) else { return }
            select(Planet.all[sender.tag])
        }

        private func select(_ planet: Planet) {
            guard parent.isActive else { return }
            if parent.hapticsEnabled { UISelectionFeedbackGenerator().selectionChanged() }
            parent.onSelect(planet)
        }

        @objc func tap(_ gesture: UITapGestureRecognizer) {
            guard let view, let components else { return }
            let location = gesture.location(in: view)
            for hit in view.hitTest(location) {
                var node: SCNNode? = hit.node
                while let candidate = node {
                    if let planet = Planet.all.first(where: { $0.id == candidate.name }) {
                        select(planet)
                        return
                    }
                    node = candidate.parent
                }
            }
            // Small spheres get a forgiving 44-point selection region as well as a native label button.
            let nearest = Planet.all.compactMap { planet -> (Planet, CGFloat)? in
                guard let node = components.bodies[planet.id] else { return nil }
                let projected = view.projectPoint(node.presentation.worldPosition)
                guard projected.z > 0, projected.z < 1 else { return nil }
                let distance = hypot(location.x - CGFloat(projected.x), location.y - CGFloat(projected.y))
                return (planet, distance)
            }.min { $0.1 < $1.1 }
            if let nearest, nearest.1 <= 22 { select(nearest.0) }
        }

        @objc func pan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began {
                angularVelocity = .zero
                previousFrame = nil
                fingerTravel = 0
            }
            guard gesture.state == .began || gesture.state == .changed || gesture.state == .ended else {
                angularVelocity = .zero
                return
            }
            let translation = gesture.translation(in: view)
            // Lower sensitivity gives the model a deliberate, heavier feel.
            rotate(horizontal: Float(translation.x) * 0.003, vertical: Float(translation.y) * 0.003)
            fingerTravel += hypot(translation.x, translation.y)
            if fingerTravel >= 12 {
                touchFeedback()
                fingerTravel = 0
            }
            if gesture.state == .ended,
                !UIAccessibility.isReduceMotionEnabled, !UIAccessibility.isVoiceOverRunning
            {
                let velocity = gesture.velocity(in: view)
                angularVelocity = SIMD2<Float>(Float(velocity.x), Float(velocity.y)) * 0.0006
            }
            gesture.setTranslation(.zero, in: view)
        }

        private func rotate(horizontal: Float, vertical: Float) {
            yaw += horizontal
            pitch = max(-0.8, min(0.8, pitch + vertical))
            components?.system.eulerAngles = SCNVector3(pitch, yaw, 0)
            layoutLabels()
            view?.setNeedsDisplay()
        }

        @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
            angularVelocity = .zero
            guard gesture.scale.isFinite, gesture.scale > 0 else { return }
            let oldZoom = zoom
            zoom = max(0.15, min(2.5, zoom / Float(gesture.scale)))
            if abs(log(zoom / oldZoom)) > 0.015 { touchFeedback() }
            gesture.scale = 1
            layout()
        }

        func apply(_ request: PlanetViewRequest) {
            guard lastRequest != request.id else { return }
            lastRequest = request.id
            angularVelocity = .zero
            switch request.action {
            case .zoomIn: zoom = max(0.15, zoom / 1.25)
            case .zoomOut: zoom = min(2.5, zoom * 1.25)
            case .rotateLeft: rotate(horizontal: -0.25, vertical: 0)
            case .rotateRight: rotate(horizontal: 0.25, vertical: 0)
            case .rotateUp: rotate(horizontal: 0, vertical: -0.25)
            case .rotateDown: rotate(horizontal: 0, vertical: 0.25)
            case .reset:
                zoom = 1
                yaw = 0
                pitch = 0
                components?.system.eulerAngles = SCNVector3Zero
            }
            layout()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool
        {
            var target = touch.view
            while let current = target {
                if current is UIControl { return false }
                target = current.superview
            }
            return true
        }

        private func touchFeedback() {
            guard parent.hapticsEnabled else { return }
            let now = CACurrentMediaTime()
            guard now - lastFeedback >= 0.10 else { return }
            lastFeedback = now
            feedback.impactOccurred(intensity: 0.7)
        }

        private func frame(_ link: CADisplayLink) {
            let elapsed = min(1.0 / 20, link.timestamp - (previousFrame ?? link.timestamp))
            previousFrame = link.timestamp
            if simd_length(angularVelocity) > 0.002 {
                rotate(
                    horizontal: angularVelocity.x * Float(elapsed),
                    vertical: angularVelocity.y * Float(elapsed))
                // Strong, time-based drag removes most momentum within a fraction of a second.
                angularVelocity *= Float(pow(0.75, elapsed * 60))
            } else {
                angularVelocity = .zero
            }
            layoutLabels()
        }

        private final class FrameProxy: NSObject {
            weak var owner: Coordinator?
            init(_ owner: Coordinator) { self.owner = owner }
            @objc func tick(_ link: CADisplayLink) { owner?.frame(link) }
        }
    }
}
