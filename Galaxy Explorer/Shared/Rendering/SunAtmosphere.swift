import SceneKit
import UIKit

// Lightweight, illustrative solar motion; this is not a plasma simulation.
@MainActor
enum SunAtmosphere {
    static let surfaceShader = """
        #pragma body

        float solarU = _geometry.texcoords[0].x;
        float solarV = _geometry.texcoords[0].y;
        float solarPhase = u_time * 0.45;
        float solarPoleFade =
            smoothstep(0.02, 0.16, solarV) *
            (1.0 - smoothstep(0.84, 0.98, solarV));

        // Periodic longitude keeps both sides of the texture seam connected.
        // Circular local offsets remain bounded instead of stretching over time.
        float solarCell = solarU * 37.699112 + sin(solarV * 25.132741);
        float solarFlowU = cos(solarPhase + solarCell) * 0.0035;
        float solarFlowV = sin(solarPhase + solarCell) * 0.0035;
        _geometry.texcoords[0].x = solarU + solarFlowU * solarPoleFade;
        _geometry.texcoords[0].y = solarV + solarFlowV * solarPoleFade;
        """

    static func addCorona(to sunNode: SCNNode) {
        let plane = SCNPlane(width: 3.3, height: 3.3)
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = coronaTexture
        material.blendMode = .add
        material.writesToDepthBuffer = false
        material.readsFromDepthBuffer = true
        material.isDoubleSided = true
        plane.firstMaterial = material

        let corona = SCNNode(geometry: plane)
        corona.name = "solarCorona"
        corona.categoryBitMask = 2
        corona.renderingOrder = 10
        // Face the camera while the solar surface remains freely rotatable.
        corona.constraints = [SCNBillboardConstraint()]
        sunNode.addChildNode(corona)
    }

    // Generate and retain one small radial texture for every solar detail scene.
    // A smooth radial falloff keeps the corona soft around the solar edge.
    private static let coronaTexture: UIImage = {
        let size = CGSize(width: 512, height: 512)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(
            size: size,
            format: format
        ).image { renderer in
            let colors =
                [
                    UIColor(red: 1, green: 0.57, blue: 0.15, alpha: 0.22).cgColor,
                    UIColor(red: 1, green: 0.53, blue: 0.12, alpha: 0.18).cgColor,
                    UIColor(red: 1, green: 0.47, blue: 0.09, alpha: 0.12).cgColor,
                    UIColor(red: 1, green: 0.40, blue: 0.06, alpha: 0.06).cgColor,
                    UIColor(red: 1, green: 0.33, blue: 0.03, alpha: 0.018).cgColor,
                    UIColor(red: 1, green: 0.28, blue: 0.02, alpha: 0).cgColor,
                ] as CFArray

            let locations: [CGFloat] = [
                0, 0.18, 0.40, 0.65, 0.85, 1,
            ]

            guard
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: locations
                )
            else {
                return
            }

            let center = CGPoint(x: 256, y: 256)

            renderer.cgContext.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 145,
                endCenter: center,
                endRadius: 256,
                options: [.drawsBeforeStartLocation]
            )
        }
    }()
}
