import AppIntents

struct PlanetWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose a planet"
    static var description = IntentDescription("Choose the planet shown on this widget.")
    @Parameter(title: "Planet", default: .mars)
    var planet: WidgetPlanet
}
