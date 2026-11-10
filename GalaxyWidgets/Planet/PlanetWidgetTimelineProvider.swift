import WidgetKit

struct PlanetWidgetTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PlanetWidgetEntry { .sample }
    func snapshot(for configuration: PlanetWidgetConfiguration, in context: Context) async
        -> PlanetWidgetEntry
    {
        PlanetWidgetEntry(date: .now, planet: configuration.planet)
    }
    func timeline(for configuration: PlanetWidgetConfiguration, in context: Context) async -> Timeline<
        PlanetWidgetEntry
    > {
        // NASA API CONTENT GOES HERE: Fetch validated content outside the view body.
        // Reference facts stay local; a static timeline avoids unnecessary refreshes.
        Timeline(entries: [PlanetWidgetEntry(date: .now, planet: configuration.planet)], policy: .never)
    }
}
