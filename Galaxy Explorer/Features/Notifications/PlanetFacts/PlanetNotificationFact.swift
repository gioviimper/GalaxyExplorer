import Foundation

struct PlanetNotificationFact {
    let planet: Planet
    let text: String
    // Short editorial facts used only by opt-in planet reminders.
    // Source: https://science.nasa.gov/solar-system/planets/
    static let all: [PlanetNotificationFact] = [
        .init(
            planet: .mercury, text: "Mercury is the smallest planet in our solar system. Take a closer look."),
        .init(
            planet: .venus,
            text: "Venus is the hottest planet in our solar system, even though Mercury is closer to the Sun."
        ),
        .init(
            planet: .earth,
            text: "Earth is the only planet where we have found life so far. Explore our home from space."),
        .init(planet: .mars, text: "Mars is home to Olympus Mons, the largest volcano in our solar system."),
        .init(
            planet: .jupiter,
            text: "Jupiter is the largest planet in our solar system. Explore the gas giant."),
        .init(
            planet: .saturn,
            text: "Saturn is not the only planet with rings. Jupiter, Uranus and Neptune have rings too."),
        .init(planet: .uranus, text: "Uranus rotates on its side. Explore this unusually tilted ice giant."),
        .init(
            planet: .neptune,
            text:
                "Neptune is the most distant planet from the Sun. Travel to the edge of the planetary family."
        ),
    ]
}
