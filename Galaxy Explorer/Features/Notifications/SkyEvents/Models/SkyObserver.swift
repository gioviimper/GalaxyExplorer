import Foundation

struct SkyObserver: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    var parameter: String {
        String(format: "%.4f,%.4f", locale: Locale(identifier: "en_US_POSIX"), latitude, longitude)
    }
    var isValid: Bool {
        latitude.isFinite && longitude.isFinite && abs(latitude) <= 90 && abs(longitude) <= 180
    }
}
