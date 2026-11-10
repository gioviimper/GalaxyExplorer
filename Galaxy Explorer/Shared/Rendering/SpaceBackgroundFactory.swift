import SceneKit
import UIKit

// A seeded star sphere surrounds the camera, so the sky fills every zoom level.
// These decorative stars are generated locally and never request location data.
enum SpaceBackgroundFactory {
    static func makeStarField() -> SCNNode {
        let sky = SCNNode()
        sky.name = "SpaceBackground"
        var seed: UInt64 = 0x53_5041_4345
        func random() -> Float {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float((seed >> 40) & 0xFFFFFF) / Float(0xFFFFFF)
        }
        let counts = [4200, 1600, 180]
        let sizes: [CGFloat] = [1.4, 2.2, 3.2]
        let colors = [
            UIColor(white: 0.64, alpha: 1),
            UIColor(red: 0.75, green: 0.83, blue: 1, alpha: 1),
            UIColor(red: 1, green: 0.94, blue: 0.82, alpha: 1),
        ]
        for group in counts.indices {
            let vertices = (0..<counts[group]).map { _ -> SCNVector3 in
                let y = random() * 2 - 1
                let angle = random() * 2 * Float.pi
                let radius = sqrt(max(0, 1 - y * y))
                return SCNVector3(cos(angle) * radius * 240, y * 240, sin(angle) * radius * 240)
            }
            let points = SCNGeometryElement(
                indices: (0..<counts[group]).map { UInt32($0) }, primitiveType: .point)
            points.pointSize = sizes[group]
            points.minimumPointScreenSpaceRadius = sizes[group] * 0.5
            points.maximumPointScreenSpaceRadius = sizes[group]
            let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices)], elements: [points])
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = colors[group]
            material.writesToDepthBuffer = false
            geometry.materials = [material]
            let batch = SCNNode(geometry: geometry)
            batch.renderingOrder = -100
            sky.addChildNode(batch)
        }
        return sky
    }
}
