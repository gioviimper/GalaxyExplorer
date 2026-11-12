import SceneKit
import UIKit
import simd

// Detail-only rings use merged geometry instead of a node for every fragment.
// Particle sizes and orbital speeds are exaggerated for a readable close-up.
@MainActor
enum PlanetRingDetail {
    static func makeRings(for planet: Planet) -> SCNNode {
        let root = SCNNode()
        root.name = "detailedPlanetRings"
        var seed: UInt64 = 72641
        for (index, band) in planet.rings.enumerated() {
            let ring = SCNNode(geometry: makeBand(band, seed: &seed))
            ring.categoryBitMask = 2
            root.addChildNode(ring)

            let fragments = SCNNode(geometry: makeFragments(band, planetID: planet.id, seed: &seed))
            fragments.name = "ringFragments"
            fragments.categoryBitMask = 2
            // Draw fragments after the transparent bands while retaining planet occlusion.
            fragments.renderingOrder = 2
            fragments.opacity = 0
            fragments.isHidden = true
            fragments.isPaused = true
            root.addChildNode(fragments)
            // Readable, illustrative orbits expose relative motion in every ring system.
            let duration =
                planet.id == "saturn"
                ? 24 + Double(index) * 9
                : 75 + Double(index) * 30
            let orbit = SCNAction.rotateBy(
                x: 0, y: .pi * 2, z: 0, duration: duration
            )
            orbit.timingMode = .linear
            fragments.runAction(.repeatForever(orbit), forKey: "iceOrbit")
        }
        return root
    }

    static func setMotionEnabled(_ enabled: Bool, on planet: SCNNode) {
        guard let rings = planet.childNode(withName: "detailedPlanetRings", recursively: false) else {
            return
        }
        for node in rings.childNodes where node.name == "ringFragments" {
            node.isPaused = !enabled || node.isHidden
        }
    }

    static func updateVisibility(on planet: SCNNode, camera: SCNNode, motionEnabled: Bool) {
        guard let rings = planet.childNode(withName: "detailedPlanetRings", recursively: false) else {
            return
        }
        let distance = simd_distance(camera.simdWorldPosition, planet.simdWorldPosition)
        let startDistance: Float = 20
        let close = min(1, max(0, (startDistance - distance) / (startDistance - 8)))
        let opacity = CGFloat(close * close * (3 - 2 * close))
        for node in rings.childNodes where node.name == "ringFragments" {
            node.isHidden = opacity < 0.01
            node.opacity = opacity
            node.isPaused = node.isHidden || !motionEnabled
        }
    }

    private static func makeBand(_ band: PlanetRingBand, seed: inout UInt64) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [SIMD4<Float>] = []
        let radialSteps = 12
        let angularSteps = 128
        for radial in 0..<radialSteps {
            let inner = Float(
                band.innerRadius + (band.outerRadius - band.innerRadius) * Double(radial)
                    / Double(radialSteps))
            let outer = Float(
                band.innerRadius + (band.outerRadius - band.innerRadius) * Double(radial + 1)
                    / Double(radialSteps))
            let shade = 0.68 + random(&seed) * 0.32
            let tint = color(band.colorHex, shade: shade, alpha: Float(band.opacity))
            for angular in 0..<angularSteps {
                let first = Float(angular) / Float(angularSteps) * .pi * 2
                let second = Float(angular + 1) / Float(angularSteps) * .pi * 2
                let a = SCNVector3(inner * cos(first), 0, inner * sin(first))
                let b = SCNVector3(outer * cos(first), 0, outer * sin(first))
                let c = SCNVector3(outer * cos(second), 0, outer * sin(second))
                let d = SCNVector3(inner * cos(second), 0, inner * sin(second))
                vertices += [a, c, b, a, d, c]
                normals += Array(repeating: SCNVector3(0, 1, 0), count: 6)
                colors += Array(repeating: tint, count: 6)
            }
        }
        return geometry(vertices: vertices, normals: normals, colors: colors, transparent: true)
    }

    private static func makeFragments(_ band: PlanetRingBand, planetID: String, seed: inout UInt64)
        -> SCNGeometry
    {
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [SIMD4<Float>] = []
        let faces = [
            [0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0],
            [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5],
        ]
        let fragmentCount = planetID == "saturn" ? 400 : 160
        let sizeFactor: Float = planetID == "jupiter" ? 0.65 : 1
        for _ in 0..<fragmentCount {
            let angle = random(&seed) * .pi * 2
            let inner = Float(band.innerRadius)
            let outer = Float(band.outerRadius)
            let radius = sqrt(inner * inner + random(&seed) * (outer * outer - inner * inner))
            let center = SIMD3<Float>(radius * cos(angle), (random(&seed) - 0.5) * 0.009, radius * sin(angle))
            let size = (0.0035 + random(&seed) * 0.0055) * sizeFactor
            let stretch = 0.6 + random(&seed) * 0.8
            let points: [SIMD3<Float>] = [
                SIMD3(size, 0, 0), SIMD3(-size, 0, 0),
                SIMD3(0, size * stretch, 0), SIMD3(0, -size * stretch, 0),
                SIMD3(0, 0, size * 0.8), SIMD3(0, 0, -size * 0.8),
            ]
            let tint = color(
                planetID == "saturn" ? 0xE8DFCB : band.colorHex, shade: 0.65 + random(&seed) * 0.35, alpha: 1)
            for face in faces {
                let a = points[face[0]]
                let b = points[face[1]]
                let c = points[face[2]]
                let normal = simd_normalize(simd_cross(b - a, c - a))
                vertices += [SCNVector3(center + a), SCNVector3(center + b), SCNVector3(center + c)]
                normals += Array(repeating: SCNVector3(normal), count: 3)
                colors += Array(repeating: tint, count: 3)
            }
        }
        return geometry(vertices: vertices, normals: normals, colors: colors, transparent: false)
    }

    private static func geometry(
        vertices: [SCNVector3], normals: [SCNVector3], colors: [SIMD4<Float>], transparent: Bool
    ) -> SCNGeometry {
        let colorData = colors.withUnsafeBytes { Data($0) }
        let colorSource = SCNGeometrySource(
            data: colorData, semantic: .color, vectorCount: colors.count,
            usesFloatComponents: true, componentsPerVector: 4, bytesPerComponent: 4,
            dataOffset: 0, dataStride: MemoryLayout<SIMD4<Float>>.stride
        )
        let indices = (0..<vertices.count).map { UInt32($0) }
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals), colorSource,
            ], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = UIColor.white
        material.isDoubleSided = transparent
        material.writesToDepthBuffer = !transparent
        geometry.firstMaterial = material
        return geometry
    }

    private static func color(_ hex: UInt32, shade: Float, alpha: Float) -> SIMD4<Float> {
        SIMD4(
            Float((hex >> 16) & 255) / 255 * shade,
            Float((hex >> 8) & 255) / 255 * shade,
            Float(hex & 255) / 255 * shade, alpha)
    }

    private static func random(_ seed: inout UInt64) -> Float {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Float((seed >> 40) & 0xFFFFFF) / Float(0x1000000)
    }
}
