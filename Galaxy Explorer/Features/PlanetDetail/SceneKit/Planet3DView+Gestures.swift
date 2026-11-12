import SceneKit
import UIKit
import simd

// Gestures behavior for the shared planet scene coordinator.
extension Planet3DView.Coordinator {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var target = touch.view
        while let current = target {
            if current is UIControl { return false }
            target = current.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer)
            || (gestureRecognizer is UIPinchGestureRecognizer
                && otherGestureRecognizer is UIPanGestureRecognizer)
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began {
            stopInertia()
            surfaceTravel = 0
            lastSurfacePulse = 0
            if let view = scnView, let planet = planetNode {
                isDraggingSurface = view.hitTest(
                    gesture.location(in: view), options: [.rootNode: planet, .categoryBitMask: 1]
                )
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
        rotatePlanet(
            horizontal: Float(translation.x) * 0.005,
            vertical: Float(translation.y) * 0.005)
        if gesture.state == .changed {
            updateSurfaceHaptics(translation: translation, velocity: gesture.velocity(in: gesture.view))
        }
        gesture.setTranslation(.zero, in: gesture.view)
        if gesture.state == .ended {
            // Direct manipulation remains available; automatic spinning stops for reduced motion.
            if UIAccessibility.isReduceMotionEnabled || UIAccessibility.isVoiceOverRunning {
                isDraggingSurface = false
                stopInertia()
                return
            }
            isDraggingSurface = false
            surfaceTravel = 0
            let velocity = gesture.velocity(in: gesture.view)
            angularVelocity = CGPoint(x: velocity.x * 0.005, y: velocity.y * 0.005)
            let link = CADisplayLink(
                target: DisplayLinkProxy(owner: self), selector: #selector(DisplayLinkProxy.tick(_:)))
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

    func updateInertia(_ link: CADisplayLink) {
        guard planetNode != nil else {
            stopInertia()
            return
        }
        let previous = lastFrameTimestamp ?? link.timestamp
        // Cap elapsed time after interruptions to avoid sudden rotation jumps.
        let delta = min(link.timestamp - previous, 1.0 / 20.0)
        lastFrameTimestamp = link.timestamp
        rotatePlanet(
            horizontal: Float(angularVelocity.x * delta),
            vertical: Float(angularVelocity.y * delta))
        // Time-based decay keeps inertia consistent across refresh rates.
        angularVelocity.x *= pow(0.87, delta * 60)
        angularVelocity.y *= pow(0.87, delta * 60)
        if abs(angularVelocity.x) < 0.006 && abs(angularVelocity.y) < 0.006 { stopInertia() }
    }

    // Compose rotations in view axes, allowing full turns beyond both poles.
    func rotatePlanet(horizontal: Float, vertical: Float) {
        guard let planetNode else { return }
        let yaw = simd_quatf(angle: horizontal, axis: SIMD3<Float>(0, 1, 0))
        let pitch = simd_quatf(angle: vertical, axis: SIMD3<Float>(1, 0, 0))
        planetNode.simdOrientation = simd_normalize(yaw * pitch * planetNode.simdOrientation)
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
            if parent.hapticsEnabled { zoomFeedback.impactOccurred(intensity: 0.75) }
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
            let reachedLimit =
                (newZ <= 1.8 && previousZ > 1.8)
                || (newZ >= 20 && previousZ < 20)
            // Measure actual relative zoom: holding at a limit produces no buzzing.
            zoomTravel += abs(log(newZ / previousZ))
            if reachedLimit {
                planetContact()
                zoomTravel = 0
                lastZoomPulse = now
            } else if zoomTravel >= 0.035 && now - lastZoomPulse >= 0.08 {
                let speed = min(1, abs(gesture.velocity) / 3)
                if parent.hapticsEnabled { zoomFeedback.impactOccurred(intensity: 0.55 + speed * 0.4) }
                zoomFeedback.prepare()
                zoomTravel = 0
                lastZoomPulse = now
            }
        }
        if gesture.state == .ended { zoomTravel = 0 }
        layoutCallouts()
        scnView?.setNeedsDisplay()
    }

    func apply(_ request: PlanetViewRequest) {
        guard lastRequestID != request.id, parent.isInteractionEnabled else { return }
        lastRequestID = request.id
        stopInertia()
        guard let cameraNode else { return }
        switch request.action {
        case .rotateLeft: rotatePlanet(horizontal: -0.25, vertical: 0)
        case .rotateRight: rotatePlanet(horizontal: 0.25, vertical: 0)
        case .rotateUp: rotatePlanet(horizontal: 0, vertical: -0.25)
        case .rotateDown: rotatePlanet(horizontal: 0, vertical: 0.25)
        case .zoomIn: cameraNode.position.z = max(1.8, cameraNode.position.z / 1.25)
        case .zoomOut: cameraNode.position.z = min(20, cameraNode.position.z * 1.25)
        case .reset:
            cameraNode.position.z = 13
            var orientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 1, 0))
            if !parent.planet.rings.isEmpty {
                orientation = simd_quatf(angle: .pi / 7, axis: SIMD3<Float>(1, 0, 0)) * orientation
            }
            planetNode?.simdOrientation = orientation
        }
        cameraNode.look(at: SCNVector3Zero)
        layoutCallouts()
        scnView?.setNeedsDisplay()
        pulse(0.55)
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        stopInertia()
        guard let scnView, let planetNode else { return }
        let hits = scnView.hitTest(
            gesture.location(in: scnView), options: [.rootNode: planetNode, .categoryBitMask: 1])
        guard let hit = hits.first(where: { $0.node === planetNode }) else { return }
        planetContact()
        // Return texture coordinates rather than Earth-specific geographic regions.
        parent.onSurfaceTapped?(hit.textureCoordinates(withMappingChannel: 0))
    }
}
