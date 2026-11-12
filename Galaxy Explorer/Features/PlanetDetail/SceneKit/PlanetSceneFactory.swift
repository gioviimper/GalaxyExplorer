import SceneKit
import UIKit
import simd

/// Builds the scene independently of SwiftUI and gesture handling.
enum PlanetSceneFactory {
    struct Components {
        let scene: SCNScene
        let cameraNode: SCNNode
        let planetNode: SCNNode
    }

    static func makeScene(for planet: Planet) -> Components {
        let scene = SCNScene()
        scene.background.contents = UIColor.black

        // A narrow field of view reduces perspective distortion.
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 22
        camera.zNear = 0.1
        camera.zFar = 500
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 13)
        scene.rootNode.addChildNode(cameraNode)
        cameraNode.addChildNode(SpaceBackgroundFactory.makeStarField())

        // Soft fill light preserves detail on the unlit side of the planet.
        let ambientNode = SCNNode()
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = planet.id == "venus" ? 450 : (planet.id == "neptune" ? 550 : 145)
        ambient.color =
            ["venus", "neptune"].contains(planet.id)
            ? UIColor.white : UIColor(red: 0.65, green: 0.58, blue: 0.54, alpha: 1)
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // The key light stays fixed while the planet rotates.
        let sunlightNode = SCNNode()
        let sunlight = SCNLight()
        sunlight.type = planet.id == "neptune" ? .omni : .directional
        sunlight.intensity = planet.id == "venus" ? 680 : (planet.id == "neptune" ? 650 : 1_150)
        sunlight.color = UIColor(red: 1, green: 0.95, blue: 0.84, alpha: 1)
        sunlightNode.light = sunlight
        sunlightNode.position = SCNVector3(2, 3, 5)
        sunlightNode.look(at: SCNVector3Zero)
        if planet.id == "venus" {
            sunlightNode.eulerAngles = SCNVector3(-0.25, -0.35, 0)
        } else if planet.id == "neptune" {
            sunlightNode.position = SCNVector3(-4, 3, 5)
        }
        scene.rootNode.addChildNode(sunlightNode)

        let planetNode = makeBody(for: planet)
        // Detail scenes share atmospheric assets with the standalone preview.
        PlanetAtmosphericLayers.add(to: planetNode, planetID: planet.id)
        if planet.kind == .star {
            SunAtmosphere.addCorona(to: planetNode)
            // Create independent prominences with randomized timing and positions.
            for _ in 0..<4 {
                SolarProminence.install(
                    on: planetNode,
                    camera: cameraNode
                )
            }
        }
        scene.rootNode.addChildNode(planetNode)
        return Components(scene: scene, cameraNode: cameraNode, planetNode: planetNode)
    }

    // The overview and detail screens share exactly the same textures, rings and star shading.
    static func makeBody(for planet: Planet, textureMaxDimension: CGFloat? = nil) -> SCNNode {
        let sphere = SCNSphere(radius: 1)
        sphere.segmentCount =
            textureMaxDimension == nil
            ? (PlanetAtmosphereStyle.style(for: planet.id) == .none ? 64 : 128)
            : 32
        let material = SCNMaterial()
        // A star stays self-lit as it rotates; planets still respond to scene lighting.
        // Constant shading preserves the bundled solar texture without a dark hemisphere.
        material.lightingModel = planet.kind == .star ? .constant : .physicallyBased
        // All textures are bundled, so switching planets never needs a download.
        let color = planet.fallbackColorHex
        let fallback = UIColor(
            red: CGFloat((color >> 16) & 0xFF) / 255,
            green: CGFloat((color >> 8) & 0xFF) / 255,
            blue: CGFloat(color & 0xFF) / 255, alpha: 1)
        // Use a bounded detail texture instead of uploading an entire 8K image.
        material.diffuse.contents =
            PlanetTextureStore.image(
                named: planet.textureName,
                maximumDimension: textureMaxDimension ?? 2048) ?? fallback
        material.metalness.contents = 0.0
        material.roughness.contents = 0.95
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .clamp
        material.diffuse.mipFilter = .linear
        material.diffuse.minificationFilter = .linear
        material.diffuse.magnificationFilter = .linear
        sphere.materials = [material]

        let planetNode = SCNNode(geometry: sphere)
        planetNode.name = planet.id
        planetNode.simdOrientation = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 1, 0))
        if !planet.rings.isEmpty {
            // Tilt the whole planet for a readable view of its equatorial rings.
            // This is a presentation angle, not an orbital or axial simulation.
            planetNode.simdOrientation =
                simd_quatf(angle: .pi / 7, axis: SIMD3<Float>(1, 0, 0)) * planetNode.simdOrientation
            if textureMaxDimension == nil {
                planetNode.addChildNode(PlanetRingDetail.makeRings(for: planet))
            } else {
                planetNode.addChildNode(
                    PlanetRingFactory.makeRings(for: planet, segments: textureMaxDimension == nil ? 128 : 64))
            }
        }
        return planetNode
    }
}
