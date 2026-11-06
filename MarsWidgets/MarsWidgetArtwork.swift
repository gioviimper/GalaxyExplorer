import UIKit

enum MarsWidgetArtwork {
    // A small, cached raster image keeps the widget independent of SceneKit and sensors.
    // This projects the bundled equirectangular texture onto a shaded sphere locally.
    static let image: UIImage = makeImage()

    private static func makeImage() -> UIImage {
        let size = 320
        let textureWidth = 512
        let textureHeight = 256
        let source = (UIImage(named: "marsTexture") ?? UIImage(named: "marstexture"))?
            .preparingThumbnail(of: CGSize(width: textureWidth, height: textureHeight))?.cgImage
        var texture = [UInt8](repeating: 0, count: textureWidth * textureHeight * 4)
        if let source {
            texture.withUnsafeMutableBytes { bytes in
                if let context = CGContext(data: bytes.baseAddress, width: textureWidth, height: textureHeight,
                    bitsPerComponent: 8, bytesPerRow: textureWidth * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) {
                    context.draw(source, in: CGRect(x: 0, y: 0, width: textureWidth, height: textureHeight))
                }
            }
        }
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for row in 0..<size {
            for column in 0..<size {
                let x = (Float(column) + 0.5) / Float(size) * 2 - 1
                let y = 1 - (Float(row) + 0.5) / Float(size) * 2
                let radiusSquared = x * x + y * y
                guard radiusSquared < 1 else { continue }
                let z = sqrt(1 - radiusSquared)
                let longitude = atan2(x, z) / (2 * Float.pi) + 0.65
                let u = longitude - floor(longitude)
                let v = 0.5 - asin(y) / Float.pi
                let tx = min(textureWidth - 1, max(0, Int(u * Float(textureWidth))))
                let ty = min(textureHeight - 1, max(0, Int(v * Float(textureHeight))))
                let sample = (ty * textureWidth + tx) * 4
                let light = max(0, -0.45 * x + 0.55 * y + 0.70 * z)
                let shade = (0.16 + 0.84 * light) * (0.85 + 0.15 * z)
                let alpha = min(1, max(0, (1 - sqrt(radiusSquared)) * Float(size) / 2))
                let output = (row * size + column) * 4
                for channel in 0..<3 {
                    let fallback: [Float] = [185, 83, 43]
                    let value = source == nil ? fallback[channel] : Float(texture[sample + channel])
                    pixels[output + channel] = UInt8(min(255, max(0, value * shade * alpha)))
                }
                pixels[output + 3] = UInt8(alpha * 255)
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { return UIImage() }
        return UIImage(cgImage: image)
    }
}

