import CoreHaptics
import SceneKit
import UIKit

// Haptics behavior for the shared planet scene coordinator.
extension Planet3DView.Coordinator {
    func prepareSurfaceHaptics() {
        guard parent.hapticsEnabled else { return }
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

    func planetContact() {
        guard parent.hapticsEnabled, scnView?.window != nil else { return }
        planetImpact.impactOccurred(intensity: 1)
        planetImpact.prepare()
    }

    func updateSurfaceHaptics(translation: CGPoint, velocity: CGPoint) {
        guard parent.hapticsEnabled, isDraggingSurface, scnView?.window != nil else { return }
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
            let texture = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35),
                ], relativeTime: 0, duration: 0.065)
            let grain = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * 0.65),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55),
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

    func pulse(_ intensity: CGFloat) {
        guard parent.hapticsEnabled, scnView?.window != nil else { return }
        let now = CACurrentMediaTime()
        guard now - lastFeedbackTime > 0.15 else { return }
        lastFeedbackTime = now
        touchFeedback.impactOccurred(intensity: intensity)
        touchFeedback.prepare()
    }

    func stopHaptics() {
        try? surfacePlayer?.stop(atTime: CHHapticTimeImmediate)
        surfacePlayer = nil
        surfaceEngine?.stop(completionHandler: nil)
        surfaceEngine = nil
    }
}
