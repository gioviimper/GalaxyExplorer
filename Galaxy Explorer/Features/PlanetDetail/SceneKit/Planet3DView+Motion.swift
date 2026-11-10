import CoreHaptics
import CoreMotion
import SceneKit
import UIKit
import simd

// Motion behavior for the shared planet scene coordinator.
extension Planet3DView.Coordinator {
    func startImmersion() {
        guard !immersionStarted else { return }
        immersionStarted = true
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(refreshMotion), name: UIApplication.didBecomeActiveNotification,
            object: nil)
        center.addObserver(
            self, selector: #selector(suspendMotion), name: UIApplication.willResignActiveNotification,
            object: nil)
        center.addObserver(
            self, selector: #selector(refreshMotion),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        center.addObserver(
            self, selector: #selector(refreshMotion),
            name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        center.addObserver(
            self, selector: #selector(refreshCalloutAppearance),
            name: UIContentSizeCategory.didChangeNotification, object: nil)
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

    @objc func suspendMotion() {
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

    @objc func refreshMotion() {
        suspendMotion()
        if immersionStarted && UIApplication.shared.applicationState == .active {
            let link = CADisplayLink(
                target: DisplayLinkProxy(owner: self), selector: #selector(DisplayLinkProxy.callouts(_:)))
            link.preferredFramesPerSecond = 30
            calloutLink = link
            link.add(to: .main, forMode: .common)
        }
        guard immersionStarted, UIApplication.shared.applicationState == .active,
            !UIAccessibility.isReduceMotionEnabled,
            !UIAccessibility.isVoiceOverRunning,
            motionManager.isDeviceMotionAvailable
        else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) {
            [weak self] motion, error in
            guard let self else { return }
            guard error == nil, let motion else {
                self.suspendMotion()
                return
            }
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
            let target = simd_clamp(
                offset * 0.7, SIMD2<Float>(repeating: -0.28), SIMD2<Float>(repeating: 0.28))
            self.parallax += (target - self.parallax) * 0.12
            if abs(camera.position.x - self.parallax.x) + abs(camera.position.y - self.parallax.y) < 0.0005 {
                return
            }
            camera.position.x = self.parallax.x
            camera.position.y = self.parallax.y
            camera.look(at: SCNVector3Zero)
            self.scnView?.setNeedsDisplay()
        }
    }
}
