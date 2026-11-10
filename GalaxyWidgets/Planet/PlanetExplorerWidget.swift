import AppIntents
import SwiftUI
import WidgetKit

// I register the supported Home sizes here and leave layout in its own file.
struct PlanetExplorerWidget: Widget {
    // Keep the installed WidgetKit identity stable across source renames.
    let kind = "MarsWidgets"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind, intent: PlanetWidgetConfiguration.self, provider: PlanetWidgetTimelineProvider()
        ) { entry in
            PlanetWidgetView(entry: entry)
        }
        .configurationDisplayName("Planet Explorer")
        .description(
            "Choose any of the eight planets and see its reference facts. Tap to open Galaxy Explorer."
        )
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Small", as: .systemSmall) { PlanetExplorerWidget() } timeline: { PlanetWidgetEntry.sample }
#Preview("Medium", as: .systemMedium) { PlanetExplorerWidget() } timeline: { PlanetWidgetEntry.sample }
