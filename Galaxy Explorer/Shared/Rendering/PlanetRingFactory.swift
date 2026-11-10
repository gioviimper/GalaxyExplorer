import SceneKit
import UIKit

// I build the rings locally, so they stay available without a network or extra textures.
enum PlanetRingFactory {
    static func makeRings(for planet: Planet, segments: Int = 128) -> SCNNode {
        let root = SCNNode()
        root.name = "\(planet.id)-rings"
        for (index, band) in planet.rings.enumerated() {
            guard band.innerRadius > 1, band.outerRadius > band.innerRadius else { continue }
            // A very thin tube forms a flat annulus in the planet's equatorial plane.
            let geometry = SCNTube(
                innerRadius: CGFloat(band.innerRadius),
                outerRadius: CGFloat(band.outerRadius), height: 0.003)
            geometry.radialSegmentCount = segments
            let material = SCNMaterial()
            material.lightingModel = .lambert
            material.isDoubleSided = true
            let color = band.colorHex
            material.diffuse.contents = UIColor(
                red: CGFloat((color >> 16) & 0xFF) / 255,
                green: CGFloat((color >> 8) & 0xFF) / 255,
                blue: CGFloat(color & 0xFF) / 255,
                alpha: CGFloat(min(1, max(0, band.opacity))))
            // Keep depth testing so the planet hides the far side of its rings.
            material.writesToDepthBuffer = false
            geometry.materials = [material]
            let node = SCNNode(geometry: geometry)
            node.name = "\(planet.id)-ring-\(index)"
            root.addChildNode(node)
        }
        return root
    }
}
