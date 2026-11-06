import SwiftUI
import WidgetKit

// I register the supported Home sizes here and leave layout in its own file.
struct MarsWidgets: Widget {
    let kind = "MarsWidgets"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MarsProvider()) { entry in
            MarsWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("Mars Explorer")
        .description("A view of Mars and its key facts. Tap to explore the planet in Galaxy Explorer.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Small", as: .systemSmall) { MarsWidgets() } timeline: { MarsEntry.sample }
#Preview("Medium", as: .systemMedium) { MarsWidgets() } timeline: { MarsEntry.sample }
