import UIKit

// Keep decoded textures bounded and reuse them when returning to a planet.
enum PlanetTextureStore {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    static func image(named name: String, maximumDimension: CGFloat) -> UIImage? {
        let key = "\(name)-\(Int(maximumDimension))" as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let original = UIImage(named: name),
            let image = original.preparingThumbnail(
                of: CGSize(width: maximumDimension, height: maximumDimension))
        else { return nil }
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }
}
