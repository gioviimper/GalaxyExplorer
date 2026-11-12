import SceneKit
import UIKit
import simd

// A small reusable arc suggests an occasional solar prominence.
// Timing, scale and motion are illustrative rather than observational data.
@MainActor
enum SolarProminence {
    static func install(on sun: SCNNode, camera: SCNNode) {
        let eruption = SCNNode()
        eruption.name = "solarProminence"
        eruption.opacity = 0
        eruption.isPaused = true
        sun.addChildNode(eruption)

        let core = material(color: UIColor(red: 1, green: 0.8, blue: 0.25, alpha: 1))
        let glow = material(color: UIColor(red: 1, green: 0.25, blue: 0.03, alpha: 0.22))
        let segments = 18
        for index in 0..<segments {
            let first = arcPoint(Float(index) / Float(segments))
            let second = arcPoint(Float(index + 1) / Float(segments))
            addSegment(from: first, to: second, radius: 0.004, material: core, to: eruption)
            addSegment(from: first, to: second, radius: 0.013, material: glow, to: eruption)
        }

        let placementState = Placement(sun: sun, camera: camera)
        let placement = SCNAction.run(
            { node in
                // SceneKit explicitly schedules this callback on the main queue.
                MainActor.assumeIsolated {
                    placementState.position(node)
                }
            }, queue: .main)

        let riseAndFade = SCNAction.customAction(duration: 3) { node, elapsed in
            let progress = min(1, max(0, Float(elapsed) / 3))
            let envelope = max(0, sin(progress * .pi))
            node.opacity = CGFloat(pow(envelope, 0.65))
            node.scale = SCNVector3(1, 0.04 + envelope * 0.96, 1)
        }
        let hide = SCNAction.fadeOut(duration: 0.15)
        eruption.runAction(
            .repeatForever(
                .sequence([
                    .wait(duration: 7, withRange: 4),
                    placement,
                    riseAndFade,
                    hide,
                ])), forKey: "solarProminenceCycle")
    }

    static func setMotionEnabled(
        _ enabled: Bool,
        on sun: SCNNode
    ) {
        for eruption in sun.childNodes
        where eruption.name == "solarProminence" {
            eruption.isPaused = !enabled
            eruption.isHidden = !enabled
        }
    }

    // Actor isolation protects node references without declaring SceneKit nodes Sendable.
    @MainActor
    private final class Placement {
        weak var sun: SCNNode?
        weak var camera: SCNNode?

        init(sun: SCNNode, camera: SCNNode) {
            self.sun = sun
            self.camera = camera
        }

        func position(_ node: SCNNode) {
            guard let sun, let camera else { return }
            // Choose a point close to the visible limb in the current viewing direction.
            let viewDirection = simd_normalize(sun.simdConvertPosition(.zero, from: camera))
            let reference =
                abs(viewDirection.y) < 0.9
                ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
            let right = simd_normalize(simd_cross(reference, viewDirection))
            let up = simd_normalize(simd_cross(viewDirection, right))
            let angle = Float.random(in: 0..<(2 * .pi))
            let radial = simd_normalize(right * cos(angle) + up * sin(angle) + viewDirection * 0.12)
            let tangent = simd_normalize(simd_cross(viewDirection, radial))
            let normal = simd_normalize(simd_cross(tangent, radial))
            let rotation = simd_float3x3(columns: (tangent, radial, normal))
            node.simdOrientation = simd_quatf(rotation)
            node.simdPosition = radial * 0.99
            node.scale = SCNVector3(1, 0.04, 1)
            node.opacity = 0
        }
    }

    private static func arcPoint(_ fraction: Float) -> SIMD3<Float> {
        let angle = fraction * .pi
        return SIMD3<Float>(-0.13 * cos(angle), 0.23 * sin(angle), 0)
    }

    private static func material(color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color
        material.blendMode = .add
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = true
        return material
    }

    private static func addSegment(
        from first: SIMD3<Float>, to second: SIMD3<Float>, radius: CGFloat,
        material: SCNMaterial, to parent: SCNNode
    ) {
        let delta = second - first
        let capsule = SCNCapsule(capRadius: radius, height: CGFloat(simd_length(delta)) + radius * 2)
        capsule.radialSegmentCount = 6
        capsule.capSegmentCount = 2
        capsule.firstMaterial = material
        let node = SCNNode(geometry: capsule)
        node.simdPosition = (first + second) * 0.5
        node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(delta))
        node.categoryBitMask = 2
        node.renderingOrder = 11
        parent.addChildNode(node)
    }
}
