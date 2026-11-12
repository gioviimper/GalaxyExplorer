import SceneKit
import SwiftUI
import UIKit

// MARK: - SceneKit bridge

struct PlanetAtmosphereScene: UIViewRepresentable {
    let planet: Planet
    let isActive: Bool
    let animateAtmosphere: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()

        view.scene = scene
        view.backgroundColor = .black
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 30

        // Use native camera controls for this standalone prototype.
        view.allowsCameraControl = true
        view.defaultCameraController.inertiaEnabled = false
        view.defaultCameraController.target = SCNVector3Zero

        let camera = SCNCamera()
        camera.fieldOfView = 40
        camera.zNear = 0.1
        camera.zFar = 100

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 5.5)

        scene.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode

        addLighting(to: scene)

        let material = makeMaterial()

        let sphere = SCNSphere(radius: 1)
        sphere.segmentCount = 128
        sphere.firstMaterial = material

        let planetNode = SCNNode(geometry: sphere)
        planetNode.eulerAngles.y = -.pi / 2

        scene.rootNode.addChildNode(planetNode)

        PlanetAtmosphericLayers.add(to: planetNode, planetID: planet.id)
        context.coordinator.planetNode = planetNode
        context.coordinator.material = material
        updateUIView(view, context: context)

        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let coordinator = context.coordinator

        let style = PlanetAtmosphereStyle.style(for: planet.id)
        let bandsEnabled = animateAtmosphere && style != .none

        if coordinator.atmosphereEnabled != bandsEnabled {
            coordinator.atmosphereEnabled = bandsEnabled

            if bandsEnabled {
                coordinator.material?.shaderModifiers = [
                    .geometry: PlanetAtmosphereShader.make(for: style)
                ]
            } else {
                coordinator.material?.shaderModifiers = nil
            }
        }

        let motionEnabled = isActive && animateAtmosphere

        if let planetNode = coordinator.planetNode {
            PlanetAtmosphericLayers.setMotionEnabled(
                motionEnabled,
                on: planetNode
            )
        }

        let hasLayers =
            coordinator.planetNode?.childNodes.contains {
                $0.name == "atmosphericLayer"
            } ?? false

        let shouldRender =
            motionEnabled && (bandsEnabled || hasLayers)

        view.isPlaying = shouldRender
        view.rendersContinuously = shouldRender
        view.setNeedsDisplay()
    }

    static func dismantleUIView(
        _ view: SCNView,
        coordinator: Coordinator
    ) {
        view.isPlaying = false
        view.rendersContinuously = false
        view.scene = nil
        coordinator.material = nil
        coordinator.planetNode = nil
    }

    private func makeMaterial() -> SCNMaterial {
        let material = SCNMaterial()

        material.lightingModel = .physicallyBased
        material.metalness.contents = 0
        material.roughness.contents = 1

        if let texture = UIImage(named: planet.textureName) {
            // Limit texture resolution to reduce GPU memory usage.
            material.diffuse.contents =
                texture.preparingThumbnail(
                    of: CGSize(width: 2048, height: 1024)
                ) ?? texture
        } else {
            // Keep missing assets visible during development.
            material.diffuse.contents = UIColor.systemGray
        }

        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .clamp
        material.diffuse.mipFilter = .linear

        return material
    }

    private func addLighting(to scene: SCNScene) {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = planet.id == "venus" ? 450 : (planet.id == "neptune" ? 550 : 350)
        ambient.color = UIColor.white

        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sunlight = SCNLight()
        sunlight.type = planet.id == "venus" ? .directional : .omni
        sunlight.intensity = planet.id == "venus" ? 680 : (planet.id == "neptune" ? 650 : 150)
        sunlight.color = UIColor(
            red: 1,
            green: 0.95,
            blue: 0.88,
            alpha: 1
        )

        let lightNode = SCNNode()
        lightNode.light = sunlight
        // Balance ambient fill with a slightly lateral key light for gentle Venus shading.
        // Add a gentle directional light to Venus.
        if planet.id == "venus" {
            lightNode.eulerAngles = SCNVector3(-0.25, -0.35, 0)
        }
        lightNode.position =
            planet.id == "venus"
            ? SCNVector3(-2, 1, 6)
            : SCNVector3(-4, 3, 5)

        scene.rootNode.addChildNode(lightNode)
    }

    final class Coordinator {
        var planetNode: SCNNode?
        var material: SCNMaterial?
        var atmosphereEnabled: Bool?
    }
}
