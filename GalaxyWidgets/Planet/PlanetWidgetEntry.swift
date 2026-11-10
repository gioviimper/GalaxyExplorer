import WidgetKit

struct PlanetWidgetEntry: TimelineEntry {
    let date: Date
    let planet: WidgetPlanet
    var gravity: String { planet.gravity }
    var temperature: String { planet.temperature }
    static let sample = PlanetWidgetEntry(date: .now, planet: .mars)
}
