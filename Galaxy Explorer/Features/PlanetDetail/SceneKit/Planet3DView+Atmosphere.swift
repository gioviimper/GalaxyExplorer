import SceneKit
import UIKit

extension Planet3DView.Coordinator {
    var automaticAtmosphereMotionAllowed: Bool {
        immersionStarted && UIApplication.shared.applicationState == .active
            && !UIAccessibility.isReduceMotionEnabled && !UIAccessibility.isVoiceOverRunning
    }

    // Atmospheric motion shares the existing screen and accessibility lifecycle.
    func setAtmosphereMotionEnabled(_ enabled: Bool) {
        guard let node = planetNode, let view = scnView else { return }
        let style = PlanetAtmosphereStyle.style(for: parent.planet.id)
        let material = node.geometry?.firstMaterial
        let hasShader = style != .none
        if enabled && hasShader {
            if material?.shaderModifiers == nil {
                material?.shaderModifiers = [.geometry: PlanetAtmosphereShader.make(for: style)]
            }
        } else {
            material?.shaderModifiers = nil
        }
        PlanetAtmosphericLayers.setMotionEnabled(enabled, on: node)
        SolarProminence.setMotionEnabled(enabled, on: node)
        PlanetRingDetail.setMotionEnabled(enabled, on: node)
        let hasLayers = node.childNodes.contains { $0.name == "atmosphericLayer" }
        let hasVisibleFragments =
            node.childNode(withName: "detailedPlanetRings", recursively: false)?
            .childNodes.contains { $0.name == "ringFragments" && !$0.isHidden } ?? false
        let shouldAnimate = enabled && (hasShader || hasLayers || hasVisibleFragments)
        view.preferredFramesPerSecond = shouldAnimate ? 30 : 60
        view.isPlaying = shouldAnimate
        view.rendersContinuously = shouldAnimate
        view.setNeedsDisplay()
    }
}
