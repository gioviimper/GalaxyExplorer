import Foundation

// Bundled celestial bodies and reference facts used by the explorer.
extension Planet {
    // These are reference averages, not live weather measurements.
    // Source: https://nssdc.gsfc.nasa.gov/planetary/factsheet/
    static let mars = Planet(
        id: "mars", name: "Mars", order: 4, textureName: "marstexture",
        gravity: "≈ 3.7 m/s²", temperature: "−65 °C",
        composition: "Rock and dust", fallbackColorHex: 0xA64724
    )

    // This asset shows the surface beneath the clouds, not Venus's visible cloud cover.
    static let venus = Planet(
        id: "venus", name: "Venus", order: 2, textureName: "venustexture",
        gravity: "≈ 8.9 m/s²", temperature: "464 °C",
        composition: "Rock", fallbackColorHex: 0xC99B62
    )

    static let mercury = Planet(
        id: "mercury", name: "Mercury", order: 1, textureName: "mercurytexture",
        gravity: "≈ 3.7 m/s²", temperature: "167 °C",
        composition: "Rock", fallbackColorHex: 0x96918A
    )

    static let earth = Planet(
        id: "earth", name: "Earth", order: 3, textureName: "earthtexture",
        gravity: "≈ 9.8 m/s²", temperature: "15 °C",
        composition: "Rock and water", fallbackColorHex: 0x3678B8
    )

    // Giant-planet temperatures describe atmospheric reference levels, not solid surfaces.
    static let jupiter = Planet(
        id: "jupiter", name: "Jupiter", order: 5, textureName: "jupitertexture",
        gravity: "≈ 23.1 m/s²", temperature: "−110 °C",
        composition: "Gas giant", fallbackColorHex: 0xBCA58B,
        rings: [.init(innerRadius: 1.30, outerRadius: 1.80, opacity: 0.08, colorHex: 0xA49A8D)]
    )

    static let saturn = Planet(
        id: "saturn", name: "Saturn", order: 6, textureName: "saturntexture",
        gravity: "≈ 9.0 m/s²", temperature: "−140 °C",
        composition: "Gas giant", fallbackColorHex: 0xD1BA88,
        rings: [
            .init(innerRadius: 1.24, outerRadius: 1.50, opacity: 0.22, colorHex: 0xB6A98C),
            .init(innerRadius: 1.53, outerRadius: 1.94, opacity: 0.85, colorHex: 0xD9CBA9),
            .init(innerRadius: 2.00, outerRadius: 2.27, opacity: 0.65, colorHex: 0xC6B793),
        ]
    )

    static let uranus = Planet(
        id: "uranus", name: "Uranus", order: 7, textureName: "uranustexture",
        gravity: "≈ 8.7 m/s²", temperature: "−195 °C",
        composition: "Ice giant", fallbackColorHex: 0xA1D7DD,
        rings: [
            .init(innerRadius: 1.65, outerRadius: 1.68, opacity: 0.30, colorHex: 0x8E9998),
            .init(innerRadius: 1.92, outerRadius: 1.96, opacity: 0.40, colorHex: 0xB4BCB8),
        ]
    )

    static let neptune = Planet(
        id: "neptune", name: "Neptune", order: 8, textureName: "neptunetexture",
        gravity: "≈ 11.0 m/s²", temperature: "−200 °C",
        composition: "Ice giant", fallbackColorHex: 0x507DBB,
        rings: [
            .init(innerRadius: 1.65, outerRadius: 1.68, opacity: 0.12, colorHex: 0x9AA2AD),
            .init(innerRadius: 2.00, outerRadius: 2.03, opacity: 0.18, colorHex: 0xBBC1C9),
        ]
    )
    // The Sun is a star. Its surface value describes the photosphere, not its core.
    // Source: https://nssdc.gsfc.nasa.gov/planetary/factsheet/sunfact.html
    static let sun = Planet(
        id: "sun", name: "Sun", order: 0, textureName: "suntexture",
        gravity: "≈ 274 m/s²", temperature: "≈ 5,500 °C",
        composition: "Hydrogen and helium", fallbackColorHex: 0xFFB52E,
        kind: .star
    )

    static let all: [Planet] = [.sun, .mercury, .venus, .earth, .mars, .jupiter, .saturn, .uranus, .neptune]
}
