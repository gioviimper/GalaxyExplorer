import SceneKit
import UIKit
import simd

/// Builds the scene independently of SwiftUI and gesture handling.
enum MarsSceneFactory {
    struct Components {
        let scene: SCNScene
        let cameraNode: SCNNode
        let marsNode: SCNNode
    }

    static func makeScene() -> Components {
        let scene = SCNScene()
        scene.background.contents = UIColor.black
        scene.rootNode.addChildNode(makeStarField())

        // A narrow field of view reduces perspective distortion.
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 22
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 13)
        scene.rootNode.addChildNode(cameraNode)

        // Soft fill light preserves detail on the unlit side of the planet.
        let ambientNode = SCNNode()
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 145
        ambient.color = UIColor(red: 0.65, green: 0.58, blue: 0.54, alpha: 1)
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // The key light stays fixed while the planet rotates.
        let sunlightNode = SCNNode()
        let sunlight = SCNLight()
        sunlight.type = .directional
        sunlight.intensity = 1_150
        sunlight.color = UIColor(red: 1, green: 0.95, blue: 0.84, alpha: 1)
        sunlightNode.light = sunlight
        sunlightNode.position = SCNVector3(2, 3, 5)
        sunlightNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(sunlightNode)

        let sphere = SCNSphere(radius: 1)
        sphere.segmentCount = 96
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        // Asset names are case-sensitive; accept the existing lowercase asset too.
        if let texture = UIImage(named: "marsTexture") ?? UIImage(named: "marstexture") {
            material.diffuse.contents = texture
        } else {
            // Keep Mars visible while the local asset is being added.
            material.diffuse.contents = UIColor(red: 0.65, green: 0.28, blue: 0.14, alpha: 1)
        }
        material.metalness.contents = 0.0
        material.roughness.contents = 0.95
        material.diffuse.mipFilter = .linear
        material.diffuse.minificationFilter = .linear
        material.diffuse.magnificationFilter = .linear
        sphere.materials = [material]

        let marsNode = SCNNode(geometry: sphere)
        marsNode.simdOrientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 1, 0))
        scene.rootNode.addChildNode(marsNode)

        return Components(scene: scene, cameraNode: cameraNode, marsNode: marsNode)
    }

    /// Creates a decorative star field locally; no downloads or location data are used.
    private static func makeStarField() -> SCNNode {
        let field = SCNNode()
        field.name = "SpaceBackground"
        // A fixed seed keeps the sky stable when SwiftUI recreates the scene.
        // These stars are decorative and do not represent a real astronomical catalog.
        var seed: UInt64 = 0x4D415253
        func randomUnit() -> Float {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Float((seed >> 40) & 0xFFFFFF) / Float(0xFFFFFF)
        }
        let counts = [420, 140, 24]
        let radii: [CGFloat] = [0.018, 0.032, 0.055]
        let colors = [UIColor(white: 0.36, alpha: 1),
                      UIColor(red: 0.63, green: 0.70, blue: 0.82, alpha: 1),
                      UIColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 1)]
        for group in counts.indices {
            let batch = SCNNode()
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = colors[group]
            let geometry = SCNSphere(radius: radii[group])
            geometry.segmentCount = 6
            geometry.materials = [material]
            for _ in 0..<counts[group] {
                let star = SCNNode(geometry: geometry)
                star.position = SCNVector3((randomUnit() - 0.5) * 48,
                                          (randomUnit() - 0.5) * 56,
                                          -35 - randomUnit() * 30)
                batch.addChildNode(star)
            }
            // Merge shared-material stars to reduce draw calls.
            field.addChildNode(batch.flattenedClone())
        }
        // Keep the sky independent of the planet's rotation. The existing motion-driven
        // camera creates gentle perspective changes without constant sky animation.
        return field
    }
}
