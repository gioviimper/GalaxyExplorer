import SwiftUI
import WidgetKit

// I draw the trail with shapes so it stays crisp and readable on the Lock Screen.
// WidgetKit controls refreshes; this widget never relies on a continuous animation.
private struct ShootingStarArtwork: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: width * 0.10, y: height * 0.78))
                    path.addQuadCurve(to: CGPoint(x: width * 0.68, y: height * 0.30),
                                      control: CGPoint(x: width * 0.35, y: height * 0.70))
                }
                .stroke(.primary.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                Path { path in
                    path.move(to: CGPoint(x: width * 0.22, y: height * 0.88))
                    path.addLine(to: CGPoint(x: width * 0.54, y: height * 0.54))
                }
                .stroke(.primary.opacity(0.4), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                Image(systemName: "sparkle")
                    .resizable().scaledToFit()
                    .frame(width: width * 0.40, height: height * 0.40)
                    .position(x: width * 0.70, y: height * 0.28)
                Image(systemName: "sparkle")
                    .resizable().scaledToFit()
                    .frame(width: width * 0.15, height: height * 0.15)
                    .opacity(0.65)
                    .position(x: width * 0.26, y: height * 0.26)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct ShootingStarEntryView: View {
    var body: some View {
        ShootingStarArtwork()
            .padding(4)
            .containerBackground(for: .widget) { Color.clear }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Shooting star")
            .accessibilityHint("Opens Galaxy Explorer")
    }
}

struct ShootingStarWidget: Widget {
    var body: some WidgetConfiguration {
        // The shared provider already supplies an offline entry; no extra fetch is needed.
        StaticConfiguration(kind: "ShootingStarWidget", provider: MarsProvider()) { _ in
            ShootingStarEntryView()
        }
        .configurationDisplayName("Shooting Star")
        .description("A little starlight for your Lock Screen. Tap to explore Mars.")
        .supportedFamilies([.accessoryCircular])
    }
}

#Preview("Lock Screen", as: .accessoryCircular) {
    ShootingStarWidget()
} timeline: {
    MarsEntry.sample
}
