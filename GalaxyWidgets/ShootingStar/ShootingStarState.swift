import Foundation

// The flight counter survives extension reloads.
enum ShootingStarState {
    static let key = "shootingStarFlight"
    static var flight: Int { UserDefaults.standard.integer(forKey: key) }
}
