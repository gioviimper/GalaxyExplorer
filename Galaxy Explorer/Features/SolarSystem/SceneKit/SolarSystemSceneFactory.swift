import SceneKit
import UIKit

// This is a navigable illustration. Sizes, distances and orbit speeds are intentionally not to scale.
enum SolarSystemSceneFactory {
    struct Components {
        let scene: SCNScene
        let system: SCNNode
        let camera: SCNNode
        let bodies: [String: SCNNode]
    }

    static func makeScene() -> Components {
        let scene = SCNScene()
        scene.background.contents = UIColor.black
        let system = SCNNode()
        scene.rootNode.addChildNode(system)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 44
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 500
        scene.rootNode.addChildNode(camera)
        camera.addChildNode(SpaceBackgroundFactory.makeStarField())

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .ambient
        fill.light?.intensity = 200
        system.addChildNode(fill)
        let sunlight = SCNNode()
        sunlight.light = SCNLight()
        sunlight.light?.type = .omni
        sunlight.light?.intensity = 1800
        sunlight.light?.attenuationStartDistance = 0
        sunlight.light?.attenuationEndDistance = 60
        system.addChildNode(sunlight)

        let radii: [Float] = [0, 3.0, 4.4, 6.0, 7.6, 10.2, 13.0, 16.0, 19.0]
        let sizes: [Float] = [1.4, 0.22, 0.38, 0.42, 0.30, 0.90, 0.75, 0.60, 0.58]
        let angles: [Float] = [0, -0.7, 1.7, 3.0, 4.7, 0.4, 2.8, 4.0, 5.5]
        var bodies: [String: SCNNode] = [:]
        for (index, planet) in Planet.all.enumerated() {
            let orbit = SCNNode()
            system.addChildNode(orbit)
            let body = PlanetSceneFactory.makeBody(for: planet, textureMaxDimension: 512)
            // Order-based lookup survives catalog reordering and safely falls back for new bodies.
            let displayIndex = min(max(planet.order, 0), radii.count - 1)
            let radius = radii[displayIndex]
            body.scale = SCNVector3(sizes[displayIndex], sizes[displayIndex], sizes[displayIndex])
            body.position = SCNVector3(
                cos(angles[displayIndex]) * radius, 0, sin(angles[displayIndex]) * radius)
            orbit.addChildNode(body)
            bodies[planet.id] = body
            if planet.kind != .star {
                let geometry = SCNTorus(ringRadius: CGFloat(radius), pipeRadius: 0.012)
                geometry.ringSegmentCount = 160
                geometry.pipeSegmentCount = 4
                let material = SCNMaterial()
                material.lightingModel = .constant
                material.diffuse.contents = UIColor(white: 0.32, alpha: 1)
                geometry.materials = [material]
                system.addChildNode(SCNNode(geometry: geometry))
                orbit.runAction(
                    .repeatForever(
                        .rotateBy(
                            x: 0, y: .pi * 2, z: 0,
                            duration: 90 + Double(index) * 24)))
            }
            body.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 70)))
        }
        return Components(scene: scene, system: system, camera: camera, bodies: bodies)
    }
}
