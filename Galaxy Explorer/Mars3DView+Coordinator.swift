import SceneKit
import UIKit
import simd
import CoreMotion
import CoreHaptics

extension Mars3DView {
    /// Owns gesture state and frame-based inertia for one Mars view.
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: Mars3DView
        weak var scnView: SCNView?
        weak var cameraNode: SCNNode?
        weak var marsNode: SCNNode?

        // Decorative anchor slots; these are not surveyed landmark coordinates.
        // Keep stable IDs when mapping future NASA content to these slots.
        private static let cardCount = 14
        private let anchors: [SIMD3<Float>] = (0..<Coordinator.cardCount).map { index in
            let y = 1 - 2 * (Float(index) + 0.5) / Float(Coordinator.cardCount)
            let radius = sqrt(max(0, 1 - y * y))
            let angle = Float(index) * .pi * (3 - sqrt(5))
            return SIMD3<Float>(cos(angle) * radius, y, sin(angle) * radius)
        }
        // NASA API CONTENT GOES HERE: Supply title, summary, and detail fields by
        // stable card ID. Cards intentionally contain no bundled editorial text.
        // Fetch through a content service, cache successful responses for offline use,
        // and update the UI on the main actor without resetting the scene.
        private struct CardContent {
            let id: String
            var title: String?
            var summary: String?
            var detail: String?
        }

        // NASA API CONTENT GOES HERE: Map a different response item to each stable ID.
        // Keep these fields nil until real API content is available; do not duplicate
        // one article across every card. Preserve the mapping when the planet rotates.
        private var cardContents: [CardContent] = (0..<Coordinator.cardCount).map { index in
            CardContent(id: String(format: "mars-card-%02d", index + 1),
                        title: nil, summary: nil, detail: nil)
        }

        private let lineCanvas = UIView()
        private var cards: [UIButton] = []
        private var lines: [CAShapeLayer] = []
        private var visible = Array(repeating: false, count: Coordinator.cardCount)
        private var leftSide = Array(repeating: false, count: Coordinator.cardCount)
        private var calloutLink: CADisplayLink?
        private var detailCard: UIButton?
        private var selectedCard: Int?

        private func installCallouts() {
            guard cards.isEmpty, let view = scnView else { return }
            lineCanvas.isUserInteractionEnabled = false
            lineCanvas.backgroundColor = .clear
            view.addSubview(lineCanvas)
            for i in anchors.indices {
                let line = CAShapeLayer()
                line.strokeColor = UIColor.systemOrange.withAlphaComponent(0.65).cgColor
                line.fillColor = UIColor.clear.cgColor
                line.lineWidth = 1
                line.opacity = 0
                lineCanvas.layer.addSublayer(line)
                lines.append(line)
                let card = UIButton(type: .system)
                var config = UIButton.Configuration.filled()
                // NASA API CONTENT GOES HERE: This slot has its own independent fields.
                let content = cardContents[i]
                config.title = content.title
                config.subtitle = content.summary
                card.accessibilityIdentifier = content.id
                card.accessibilityLabel = content.title ?? "Empty information card \(i + 1)"
                card.accessibilityHint = "Opens an empty detail panel"
                config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                    var result = attributes
                    result.font = UIFont.preferredFont(forTextStyle: .subheadline)
                    return result
                }
                config.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                    var result = attributes
                    result.font = UIFont.preferredFont(forTextStyle: .caption1)
                    return result
                }
                config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
                // Leave the visible card empty until NASA content is provided.
                config.baseForegroundColor = .white
                config.baseBackgroundColor = UIColor(red: 0.13, green: 0.09, blue: 0.08, alpha: 0.95)
                config.cornerStyle = .medium
                card.configuration = config
                card.layer.borderWidth = 0.5
                card.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
                card.layer.cornerRadius = 12
                card.tag = i
                card.alpha = 0
                card.isUserInteractionEnabled = false
                card.accessibilityElementsHidden = true
                card.addTarget(self, action: #selector(openCard(_:)), for: .touchUpInside)
                view.addSubview(card)
                cards.append(card)
            }
            let detail = UIButton(type: .system)
            detail.isHidden = true
            detail.addTarget(self, action: #selector(closeCard), for: .touchUpInside)
            view.addSubview(detail)
            detailCard = detail
        }

        // TODO(API): Show the selected card's cached detail immediately. If a detail
        // endpoint exists, request it through the content service and refresh this
        // panel on the main actor only if the same stable card ID is still selected.
        // Cancel obsolete requests on close; retain readable fallback text on failure.
        @objc private func openCard(_ sender: UIButton) {
            selectedCard = sender.tag
            pulse(0.55)
            guard let detail = detailCard else { return }
            var config = UIButton.Configuration.filled()
            // NASA API CONTENT GOES HERE: Open the same item's detail, not shared text.
            // Each stable ID keeps its own title, summary, and full detail content.
            let content = cardContents[sender.tag]
            config.title = content.title
            config.subtitle = content.detail
            config.image = UIImage(systemName: "xmark")
            config.baseForegroundColor = .white
            config.baseBackgroundColor = UIColor(red: 0.16, green: 0.10, blue: 0.08, alpha: 0.98)
            config.cornerStyle = .large
            config.contentInsets = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
            detail.configuration = config
            detail.accessibilityLabel = content.title ?? "Close empty information panel"
            detail.accessibilityHint = "Closes the detail panel"
            detail.isHidden = false
            detail.alpha = 0
            detail.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            layoutCallouts()
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.25) {
                detail.alpha = 1
                detail.transform = .identity
            }
        }

        @objc private func closeCard() {
            selectedCard = nil
            detailCard?.isHidden = true
        }

        // TODO(API): Keep all networking and JSON decoding out of this frame callback.
        // For actual landmarks, validate coordinates and texture alignment before
        // replacing the illustrative anchors; general articles have no surface location.
        @objc private func layoutCallouts() {
            guard let view = scnView, let planet = marsNode, let camera = cameraNode,
                  view.window != nil, view.bounds.width > 0, cards.count == anchors.count else { return }
            lineCanvas.frame = view.bounds
            let centerPoint = view.projectPoint(SCNVector3(planet.simdWorldPosition))
            let edge = view.projectPoint(SCNVector3(planet.simdWorldPosition + SIMD3<Float>(1, 0, 0)))
            let radius = abs(CGFloat(edge.x - centerPoint.x))
            let width = view.bounds.width
            let top = view.safeAreaInsets.top + 16
            let bottom = max(top + 80, view.bounds.height - view.safeAreaInsets.bottom - 92)
            let cardWidth = min(158, (width - 56) / 2)
            let cardHeights = cards.map { max(64, $0.sizeThatFits(CGSize(width: cardWidth, height: 1000)).height) }
            // Choose the most front-facing slots; show at most three at a time.
            // A small score bias keeps existing cards stable during slow rotation.
            let ranked = anchors.indices.compactMap { i -> (Int, Float, Bool)? in
                let world = planet.simdConvertPosition(anchors[i], to: nil)
                let normal = simd_normalize(world - planet.simdWorldPosition)
                let facing = simd_dot(normal, simd_normalize(camera.simdWorldPosition - world))
                let projected = view.projectPoint(SCNVector3(world))
                let point = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                guard projected.z > 0, projected.z < 1, view.bounds.contains(point),
                      facing > (visible[i] ? 0.04 : 0.12) else { return nil }
                return (i, facing + (visible[i] ? 0.08 : 0), point.x < width / 2)
            }.sorted { $0.1 > $1.1 }
            var allowed = Set<Int>()
            var leftCount = 0
            var rightCount = 0
            for item in ranked where allowed.count < 3 {
                if item.2 && leftCount < 2 { allowed.insert(item.0); leftCount += 1 }
                if !item.2 && rightCount < 2 { allowed.insert(item.0); rightCount += 1 }
            }
            var items: [(Int, CGPoint, Bool)] = []
            for i in anchors.indices {
                let world = planet.simdConvertPosition(simd_normalize(anchors[i]), to: nil)
                let projected = view.projectPoint(SCNVector3(world))
                let point = CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
                let showing = allowed.contains(i)
                if showing != visible[i] {
                    visible[i] = showing
                    cards[i].isUserInteractionEnabled = showing
                    cards[i].accessibilityElementsHidden = !showing
                    UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.18) { self.cards[i].alpha = showing ? 1 : 0 }
                    if !showing && selectedCard == i { closeCard() }
                }
                if showing {
                    if point.x < width / 2 - 20 { leftSide[i] = true }
                    if point.x > width / 2 + 20 { leftSide[i] = false }
                    items.append((i, point, leftSide[i]))
                } else {
                    CATransaction.begin(); CATransaction.setDisableActions(true)
                    lines[i].opacity = 0
                    CATransaction.commit()
                }
            }
            for left in [true, false] {
                let group = items.filter { $0.2 == left }.sorted { $0.1.y < $1.1.y }
                let largest = group.map { cardHeights[$0.0] }.max() ?? 64
                let gap = max(largest + 12, 80)
                var previous = top - gap
                for (rank, item) in group.enumerated() {
                    let (i, point, _) = item
                    let remaining = CGFloat(group.count - rank - 1)
                    let outerY = point.y < CGFloat(centerPoint.y) ? CGFloat(centerPoint.y) - radius - 100 : CGFloat(centerPoint.y) + radius + 24
                    let y = max(previous + gap, min(bottom - remaining * gap, max(top, outerY)))
                    previous = y
                    let frame = CGRect(x: left ? 20 : width - cardWidth - 20, y: min(y, view.bounds.height - view.safeAreaInsets.bottom - cardHeights[i] - 16), width: cardWidth, height: cardHeights[i])
                    cards[i].frame = frame
                    let path = UIBezierPath()
                    path.move(to: point)
                    path.addLine(to: CGPoint(x: left ? frame.maxX : frame.minX, y: frame.midY))
                    path.move(to: CGPoint(x: point.x + 3, y: point.y))
                    path.addArc(withCenter: point, radius: 3, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    CATransaction.begin(); CATransaction.setDisableActions(true)
                    lines[i].path = path.cgPath
                    lines[i].opacity = 1
                    CATransaction.commit()
                }
            }
            if let detail = detailCard, !detail.isHidden {
                let height = min(280, max(180, detail.sizeThatFits(CGSize(width: width - 32, height: 300)).height))
                detail.bounds = CGRect(x: 0, y: 0, width: width - 32, height: height)
                detail.center = CGPoint(x: width / 2, y: view.bounds.height - view.safeAreaInsets.bottom - height / 2 - 16)
                view.bringSubviewToFront(detail)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var target = touch.view
            while let current = target {
                if current is UIControl { return false }
                target = current.superview
            }
            return true
        }

        private let zoomFeedback = UIImpactFeedbackGenerator(style: .rigid)
        private var zoomTravel: Float = 0
        private var lastZoomPulse: CFTimeInterval = 0

        private let planetImpact = UIImpactFeedbackGenerator(style: .heavy)
        private let surfaceFallback = UIImpactFeedbackGenerator(style: .rigid)
        private var surfaceEngine: CHHapticEngine?
        private var surfacePlayer: CHHapticPatternPlayer?
        private var isDraggingSurface = false
        private var surfaceTravel: CGFloat = 0
        private var lastSurfacePulse: CFTimeInterval = 0

        private func prepareSurfaceHaptics() {
            planetImpact.prepare()
            surfaceFallback.prepare()
            guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
            do {
                if surfaceEngine == nil {
                    let engine = try CHHapticEngine()
                    engine.playsHapticsOnly = true
                    engine.isAutoShutdownEnabled = true
                    engine.resetHandler = { [weak self] in
                        Task { @MainActor [weak self] in
                            self?.surfacePlayer = nil
                            self?.surfaceEngine = nil
                        }
                    }
                    surfaceEngine = engine
                }
                try surfaceEngine?.start()
            } catch {
                surfaceEngine = nil
            }
        }

        private func planetContact() {
            guard scnView?.window != nil else { return }
            planetImpact.impactOccurred(intensity: 1)
            planetImpact.prepare()
        }

        private func updateSurfaceHaptics(translation: CGPoint, velocity: CGPoint) {
            guard isDraggingSurface, scnView?.window != nil else { return }
            surfaceTravel += hypot(translation.x, translation.y)
            let now = CACurrentMediaTime()
            // Texture follows finger travel, not the render loop or free-spinning inertia.
            // Short finite bursts end naturally when the finger stops moving.
            guard surfaceTravel >= 8, now - lastSurfacePulse >= 0.075 else { return }
            surfaceTravel = 0
            lastSurfacePulse = now
            let speed = min(1, hypot(velocity.x, velocity.y) / 900)
            let intensity = Float(0.65 + speed * 0.30)
            do {
                guard let engine = surfaceEngine else {
                    surfaceFallback.impactOccurred(intensity: CGFloat(intensity))
                    surfaceFallback.prepare()
                    return
                }
                try engine.start()
                let texture = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
                ], relativeTime: 0, duration: 0.065)
                let grain = CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.65),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
                ], relativeTime: 0)
                let pattern = try CHHapticPattern(events: [texture, grain], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                surfacePlayer = player
                try player.start(atTime: CHHapticTimeImmediate)
            } catch {
                surfaceEngine = nil
                surfaceFallback.impactOccurred(intensity: CGFloat(intensity))
                surfaceFallback.prepare()
            }
        }

        private let motionManager = CMMotionManager()
        private let touchFeedback = UIImpactFeedbackGenerator(style: .soft)
        private var lastFeedbackTime: CFTimeInterval = 0
        private var referenceAttitude: simd_quatf?
        private var motionOrientation: UIInterfaceOrientation?
        private var parallax = SIMD2<Float>.zero
        private var immersionStarted = false

        private func pulse(_ intensity: CGFloat) {
            guard scnView?.window != nil else { return }
            let now = CACurrentMediaTime()
            guard now - lastFeedbackTime > 0.15 else { return }
            lastFeedbackTime = now
            touchFeedback.impactOccurred(intensity: intensity)
            touchFeedback.prepare()
        }

        func startImmersion() {
            guard !immersionStarted else { return }
            immersionStarted = true
            let center = NotificationCenter.default
            center.addObserver(self, selector: #selector(refreshMotion), name: UIApplication.didBecomeActiveNotification, object: nil)
            center.addObserver(self, selector: #selector(suspendMotion), name: UIApplication.willResignActiveNotification, object: nil)
            center.addObserver(self, selector: #selector(refreshMotion), name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
            touchFeedback.prepare()
            planetImpact.prepare()
            surfaceFallback.prepare()
            installCallouts()
            refreshMotion()
        }

        func stopImmersion() {
            immersionStarted = false
            NotificationCenter.default.removeObserver(self)
            suspendMotion()
        }

        @objc private func suspendMotion() {
            zoomTravel = 0
            lastZoomPulse = 0
            isDraggingSurface = false
            surfaceTravel = 0
            try? surfacePlayer?.stop(atTime: CHHapticTimeImmediate)
            surfacePlayer = nil
            surfaceEngine?.stop(completionHandler: nil)
            calloutLink?.invalidate()
            calloutLink = nil
            motionManager.stopDeviceMotionUpdates()
            referenceAttitude = nil
            motionOrientation = nil
            parallax = .zero
            cameraNode?.position.x = 0
            cameraNode?.position.y = 0
            cameraNode?.look(at: SCNVector3Zero)
            stopInertia()
            scnView?.setNeedsDisplay()
        }

        @objc private func refreshMotion() {
            suspendMotion()
            if immersionStarted && UIApplication.shared.applicationState == .active {
                let link = CADisplayLink(target: DisplayLinkProxy(owner: self), selector: #selector(DisplayLinkProxy.callouts(_:)))
                link.preferredFramesPerSecond = 30
                calloutLink = link
                link.add(to: .main, forMode: .common)
            }
            guard immersionStarted, UIApplication.shared.applicationState == .active,
                  !UIAccessibility.isReduceMotionEnabled,
                  motionManager.isDeviceMotionAvailable else { return }
            motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
            motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, error in
                guard let self else { return }
                guard error == nil, let motion else { self.suspendMotion(); return }
                guard self.scnView?.window != nil, let camera = self.cameraNode else { return }
                let q = motion.attitude.quaternion
                let attitude = simd_quatf(ix: Float(q.x), iy: Float(q.y), iz: Float(q.z), r: Float(q.w))
                let scene = self.scnView?.window?.windowScene
                let orientation: UIInterfaceOrientation
                if #available(iOS 26.0, *) {
                    orientation = scene?.effectiveGeometry.interfaceOrientation ?? .portrait
                } else {
                    orientation = scene?.interfaceOrientation ?? .portrait
                }
                if self.referenceAttitude == nil || self.motionOrientation != orientation {
                    self.referenceAttitude = attitude
                    self.motionOrientation = orientation
                }
                guard let reference = self.referenceAttitude else { return }
                let direction = (reference.inverse * attitude).act(SIMD3<Float>(0, 0, 1))
                var offset = SIMD2<Float>(direction.x, direction.y)
                switch orientation {
                case .landscapeLeft: offset = SIMD2<Float>(offset.y, -offset.x)
                case .landscapeRight: offset = SIMD2<Float>(-offset.y, offset.x)
                case .portraitUpsideDown: offset = -offset
                default: break
                }
                let target = simd_clamp(offset * 0.7, SIMD2<Float>(repeating: -0.28), SIMD2<Float>(repeating: 0.28))
                self.parallax += (target - self.parallax) * 0.12
                if abs(camera.position.x - self.parallax.x) + abs(camera.position.y - self.parallax.y) < 0.0005 { return }
                camera.position.x = self.parallax.x
                camera.position.y = self.parallax.y
                camera.look(at: SCNVector3Zero)
                self.scnView?.setNeedsDisplay()
            }
        }

        private var displayLink: CADisplayLink?
        private var angularVelocity = CGPoint.zero
        private var lastFrameTimestamp: CFTimeInterval?

        // CADisplayLink retains its target; a weak proxy avoids a retain cycle.
        private final class DisplayLinkProxy: NSObject {
            weak var owner: Coordinator?
            init(owner: Coordinator) { self.owner = owner }
            @objc func callouts(_ link: CADisplayLink) {
                guard let owner else { link.invalidate(); return }
                owner.layoutCallouts()
            }
            @objc func tick(_ link: CADisplayLink) {
                guard let owner else { link.invalidate(); return }
                owner.updateInertia(link)
            }
        }

        init(_ parent: Mars3DView) { self.parent = parent }
        deinit {
            surfaceEngine?.stop(completionHandler: nil)
            calloutLink?.invalidate()
            displayLink?.invalidate()
            motionManager.stopDeviceMotionUpdates()
            NotificationCenter.default.removeObserver(self)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer)
                || (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began {
                stopInertia()
                surfaceTravel = 0
                lastSurfacePulse = 0
                if let view = scnView, let planet = marsNode {
                    isDraggingSurface = view.hitTest(gesture.location(in: view), options: [.rootNode: planet])
                        .contains { $0.node === planet }
                }
                if isDraggingSurface {
                    prepareSurfaceHaptics()
                    planetContact()
                    lastSurfacePulse = CACurrentMediaTime()
                }
            }
            guard gesture.state == .began || gesture.state == .changed || gesture.state == .ended else {
                isDraggingSurface = false
                surfaceTravel = 0
                stopInertia()
                return
            }
            let translation = gesture.translation(in: gesture.view)
            rotatePlanet(horizontal: Float(translation.x) * 0.005,
                         vertical: Float(translation.y) * 0.005)
            if gesture.state == .changed {
                updateSurfaceHaptics(translation: translation, velocity: gesture.velocity(in: gesture.view))
            }
            gesture.setTranslation(.zero, in: gesture.view)
            if gesture.state == .ended {
                isDraggingSurface = false
                surfaceTravel = 0
                let velocity = gesture.velocity(in: gesture.view)
                angularVelocity = CGPoint(x: velocity.x * 0.005, y: velocity.y * 0.005)
                let link = CADisplayLink(target: DisplayLinkProxy(owner: self), selector: #selector(DisplayLinkProxy.tick(_:)))
                displayLink = link
                link.add(to: .main, forMode: .common)
            }
        }

        func stopInertia() {
            displayLink?.invalidate()
            displayLink = nil
            angularVelocity = .zero
            lastFrameTimestamp = nil
        }

        private func updateInertia(_ link: CADisplayLink) {
            guard marsNode != nil else { stopInertia(); return }
            let previous = lastFrameTimestamp ?? link.timestamp
            // Cap elapsed time after interruptions to avoid sudden rotation jumps.
            let delta = min(link.timestamp - previous, 1.0 / 20.0)
            lastFrameTimestamp = link.timestamp
            rotatePlanet(horizontal: Float(angularVelocity.x * delta),
                         vertical: Float(angularVelocity.y * delta))
            // Time-based decay keeps inertia consistent across refresh rates.
            angularVelocity.x *= pow(0.87, delta * 60)
            angularVelocity.y *= pow(0.87, delta * 60)
            if abs(angularVelocity.x) < 0.006 && abs(angularVelocity.y) < 0.006 { stopInertia() }
        }

        // Compose rotations in view axes, allowing full turns beyond both poles.
        private func rotatePlanet(horizontal: Float, vertical: Float) {
            guard let marsNode else { return }
            let yaw = simd_quatf(angle: horizontal, axis: SIMD3<Float>(0, 1, 0))
            let pitch = simd_quatf(angle: vertical, axis: SIMD3<Float>(1, 0, 0))
            marsNode.simdOrientation = simd_normalize(yaw * pitch * marsNode.simdOrientation)
            // Synchronize visible card IDs with both direct dragging and inertia.
            layoutCallouts()
            scnView?.setNeedsDisplay()
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .began {
                stopInertia()
                zoomTravel = 0
                lastZoomPulse = CACurrentMediaTime()
                zoomFeedback.prepare()
                zoomFeedback.impactOccurred(intensity: 0.75)
            }
            guard gesture.state == .began || gesture.state == .changed || gesture.state == .ended else {
                zoomTravel = 0
                return
            }
            guard let cameraNode, gesture.scale.isFinite, gesture.scale > 0 else { return }
            let previousZ = cameraNode.position.z
            // Allow close inspection while leaving room for clipping and parallax.
            let newZ = max(1.8, min(20, previousZ / Float(gesture.scale)))
            cameraNode.position.z = newZ
            cameraNode.look(at: SCNVector3Zero)
            gesture.scale = 1

            if abs(newZ - previousZ) > 0.0001 {
                let now = CACurrentMediaTime()
                let reachedLimit = (newZ <= 1.8 && previousZ > 1.8)
                    || (newZ >= 20 && previousZ < 20)
                // Measure actual relative zoom: holding at a limit produces no buzzing.
                zoomTravel += abs(log(newZ / previousZ))
                if reachedLimit {
                    planetContact()
                    zoomTravel = 0
                    lastZoomPulse = now
                } else if zoomTravel >= 0.035 && now - lastZoomPulse >= 0.08 {
                    let speed = min(1, abs(gesture.velocity) / 3)
                    zoomFeedback.impactOccurred(intensity: 0.55 + speed * 0.4)
                    zoomFeedback.prepare()
                    zoomTravel = 0
                    lastZoomPulse = now
                }
            }
            if gesture.state == .ended { zoomTravel = 0 }
            layoutCallouts()
            scnView?.setNeedsDisplay()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            stopInertia()
            guard let scnView, let marsNode else { return }
            let hits = scnView.hitTest(gesture.location(in: scnView), options: [.rootNode: marsNode])
            guard let hit = hits.first(where: { $0.node === marsNode }) else { return }
            planetContact()
            // Return texture coordinates rather than Earth-specific geographic regions.
            parent.onSurfaceTapped?(hit.textureCoordinates(withMappingChannel: 0))
        }
    }
}
