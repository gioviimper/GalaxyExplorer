import Foundation

// I keep appearance and reference facts separate from gestures and scene rendering.
// Add a bundled equirectangular texture and a configuration here for another planet.
struct Planet: Identifiable, Hashable {
    let id: String
    let name: String
    let order: Int
    let textureName: String
    let gravity: String
    let temperature: String
    let composition: String
    let fallbackColorHex: UInt32
    var rings: [PlanetRingBand] = []
    var kind: Kind = .planet
    // Leave nil to follow the body's palette, or set a separate card color here.
    var cardTintHex: UInt32? = nil

    enum Kind: String, Hashable {
        case planet
        case star
    }

    var temperatureLabel: String {
        kind == .star ? "Surface temperature" : "Avg. temperature"
    }

    var systemLabel: String {
        kind == .star ? "SOLAR SYSTEM · STAR" : String(format: "SOLAR SYSTEM · %02d", order)
    }
}
