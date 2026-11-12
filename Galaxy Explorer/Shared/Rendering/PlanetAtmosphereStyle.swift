// MARK: - Planet-specific effects

enum PlanetAtmosphereStyle: Equatable {
    case none
    case jupiterBands
    case saturnBands
    case uranusVortices
    case neptuneVortices
    case solarPlasma

    static func style(for planetID: String) -> Self {
        switch planetID {
        case "sun":
            return .solarPlasma

        case "jupiter":
            return .jupiterBands

        case "saturn":
            return .saturnBands

        case "uranus":
            return .uranusVortices

        case "neptune":
            return .neptuneVortices

        default:
            // Rocky surfaces and cloud layers need separate effects.
            return .none
        }
    }
}
