import SwiftUI
import WidgetKit

struct ShootingStarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ShootingStarWidget", provider: ShootingStarTimelineProvider()) { entry in
            ShootingStarWidgetView(entry: entry)
        }
        .configurationDisplayName("Shooting Star")
        .description("Tap to send a little starlight across your Lock Screen.")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview("Horizontal Lock Screen", as: .accessoryRectangular) {
    ShootingStarWidget()
} timeline: {
    ShootingStarEntry(date: .now, flight: 0)
    ShootingStarEntry(date: .now.addingTimeInterval(5), flight: 1)
}
