import CoreImage
import CoreImage.CIFilterBuiltins
import SceneKit
import UIKit

// MARK: - Independent atmospheric layers

@MainActor
enum PlanetAtmosphericLayers {
    // Reuse bounded source images and the processed Venus texture across visits.
    private static let processedTextures: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 8 * 1024 * 1024
        cache.countLimit = 2
        return cache
    }()
    private static let imageContext = CIContext(options: [.cacheIntermediates: false])

    static func add(
        to planetNode: SCNNode,
        planetID: String
    ) {
        let configuration:
            (
                texture: String,
                opacity: CGFloat,
                duration: TimeInterval,
                direction: CGFloat
            )

        switch planetID {
        case "earth":
            configuration = ("earth_clouds", 0.85, 100, 1)

        case "venus":
            configuration = ("venus_clouds", 1.0, 140, -1)

        case "mars":
            configuration = ("mars_dust", 0.20, 130, 1)

        case "saturn":
            configuration = ("saturn_clouds", 0.20, 130, 1)

        default:
            return
        }

        // Reuse a bounded source texture; missing optional layers stay absent.
        guard
            let image = PlanetTextureStore.image(
                named: configuration.texture, maximumDimension: 2048
            )
        else { return }

        let material = SCNMaterial()

        // Preserve soft surface shading.
        material.lightingModel = .lambert

        if planetID == "venus" {
            // Give the clouds a warm cream tint.
            material.multiply.contents = UIColor(
                red: 0.95,
                green: 0.82,
                blue: 0.58,
                alpha: 1
            )
        }

        let resizedImage = image

        var cloudTexture = resizedImage

        // Increase Venus cloud contrast once when creating the layer.
        let cacheKey = "\(configuration.texture)-contrast-1.25-dust-blur8" as NSString
        if let cached = processedTextures.object(forKey: cacheKey) {
            cloudTexture = cached
        } else if planetID == "venus", let input = CIImage(image: resizedImage) {
            let filter = CIFilter.colorControls()
            filter.inputImage = input
            filter.contrast = 1.25
            filter.brightness = 0
            filter.saturation = 1

            if let output = filter.outputImage,
                let rendered = imageContext.createCGImage(
                    output,
                    from: input.extent
                )
            {
                cloudTexture = UIImage(
                    cgImage: rendered,
                    scale: resizedImage.scale,
                    orientation: resizedImage.imageOrientation
                )
                processedTextures.setObject(
                    cloudTexture, forKey: cacheKey,
                    cost: rendered.width * rendered.height * 4
                )
            }
        } else if planetID == "mars", let input = CIImage(image: resizedImage) {
            // Soften hard mask edges once, then reuse the processed texture.
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = input.clampedToExtent()
            blur.radius = 8
            if let output = blur.outputImage,
                let rendered = imageContext.createCGImage(output, from: input.extent)
            {
                cloudTexture = UIImage(cgImage: rendered)
                processedTextures.setObject(
                    cloudTexture, forKey: cacheKey, cost: rendered.width * rendered.height * 4
                )
            }
        }

        material.diffuse.contents = cloudTexture
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .clamp
        material.diffuse.mipFilter = .linear

        material.transparency = configuration.opacity
        material.blendMode = .alpha
        material.isDoubleSided = false
        material.readsFromDepthBuffer = true
        material.writesToDepthBuffer = false
        if planetID == "mars" {
            MarsDustAtmosphere.configure(material)
        }

        let sphere = SCNSphere(radius: 1.012)
        sphere.segmentCount = 96
        sphere.firstMaterial = material

        let layer = SCNNode(geometry: sphere)
        layer.name = "atmosphericLayer"
        // Keep decorative clouds out of surface gesture hit tests.
        layer.categoryBitMask = 2
        layer.renderingOrder = 10
        layer.isPaused = true

        planetNode.addChildNode(layer)

        // Speeds are illustrative rather than scientific measurements.
        let rotation = SCNAction.rotateBy(
            x: 0,
            y: configuration.direction * .pi * 2,
            z: 0,
            duration: configuration.duration
        )
        rotation.timingMode = .linear

        layer.runAction(
            .repeatForever(rotation),
            forKey: "atmosphericRotation"
        )
    }

    static func setMotionEnabled(
        _ enabled: Bool,
        on planetNode: SCNNode
    ) {
        for layer in planetNode.childNodes
        where layer.name == "atmosphericLayer" {
            // Resume from the current position without restarting.
            layer.isPaused = !enabled
            if let material = layer.geometry?.firstMaterial {
                MarsDustAtmosphere.setMotionEnabled(enabled, material: material)
            }
        }
    }
}
