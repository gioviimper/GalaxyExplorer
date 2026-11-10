import AppIntents

// Native widget settings allow each Home widget to choose its own planet.
enum WidgetPlanet: String, AppEnum {
    case mercury, venus, earth, mars, jupiter, saturn, uranus, neptune
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Planet"
    static var caseDisplayRepresentations: [WidgetPlanet: DisplayRepresentation] = [
        .mercury: "Mercury",
        .venus: "Venus",
        .earth: "Earth",
        .mars: "Mars",
        .jupiter: "Jupiter",
        .saturn: "Saturn",
        .uranus: "Uranus",
        .neptune: "Neptune",
    ]
    var name: String { rawValue.capitalized }
    // Reference averages match the app; these are not live measurements.
    var gravity: String {
        switch self {
        case .mercury: return "≈ 3.7 m/s²"
        case .venus: return "≈ 8.9 m/s²"
        case .earth: return "≈ 9.8 m/s²"
        case .mars: return "≈ 3.7 m/s²"
        case .jupiter: return "≈ 23.1 m/s²"
        case .saturn: return "≈ 9.0 m/s²"
        case .uranus: return "≈ 8.7 m/s²"
        case .neptune: return "≈ 11.0 m/s²"
        }
    }
    // Reference averages match the app; these are not live measurements.
    var temperature: String {
        switch self {
        case .mercury: return "167 °C"
        case .venus: return "464 °C"
        case .earth: return "15 °C"
        case .mars: return "−65 °C"
        case .jupiter: return "−110 °C"
        case .saturn: return "−140 °C"
        case .uranus: return "−195 °C"
        case .neptune: return "−200 °C"
        }
    }
}
