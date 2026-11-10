import Foundation

// Ring radii are relative to the normalized planet radius of 1.
// These illustrative bands are not measured ring maps or a simulation of individual particles.
struct PlanetRingBand: Hashable {
    let innerRadius: Double
    let outerRadius: Double
    let opacity: Double
    let colorHex: UInt32
}
