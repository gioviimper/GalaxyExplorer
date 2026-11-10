import SwiftUI
import WidgetKit

struct PlanetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    @Environment(\.dynamicTypeSize) private var typeSize
    let entry: PlanetWidgetEntry

    // Full-color artwork uses a dark sky; tinted and background-free widgets use system text.
    private var textColor: Color {
        renderingMode == .fullColor && showsBackground ? .white : .primary
    }

    var body: some View {
        Group {
            if family == .systemSmall { smallWidget } else { mediumWidget }
        }
        .foregroundStyle(textColor)
        .containerBackground(for: .widget) { WidgetStarfield() }
    }

    private var planet: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let hasRings = entry.planet == .saturn
            ZStack {
                if hasRings {
                    // Split the illustrative rings so the planet hides their far side.
                    Ellipse().trim(from: 0.5, to: 1)
                        .stroke(Color(red: 0.78, green: 0.72, blue: 0.58), lineWidth: side * 0.065)
                        .frame(width: side * 0.88, height: side * 0.28)
                        .rotationEffect(.degrees(-20))
                }
                Image(uiImage: PlanetWidgetArtwork.image(for: entry.planet))
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFit()
                    .frame(width: side * (hasRings ? 0.57 : 1), height: side * (hasRings ? 0.57 : 1))
                if hasRings {
                    Ellipse().trim(from: 0, to: 0.5)
                        .stroke(Color(red: 0.78, green: 0.72, blue: 0.58), lineWidth: side * 0.065)
                        .frame(width: side * 0.88, height: side * 0.28)
                        .rotationEffect(.degrees(-20))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityHidden(true)
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.planet.name).font(.headline)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.orange)
                    .accessibilityHidden(true)
            }
            planet.frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("Explore \(entry.planet.name)")
                .font(.caption2)
                .foregroundStyle(textColor.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Galaxy Explorer")
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            planet.frame(maxWidth: typeSize.isAccessibilitySize ? 72 : 110, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.planet.name).font(.title2.weight(.semibold))
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.orange)
                        .accessibilityHidden(true)
                }
                // Larger text keeps the primary identity and action instead of squeezing every fact.
                if !typeSize.isAccessibilitySize {
                    fact("Gravity", entry.gravity)
                    fact("Avg. temp.", entry.temperature)
                }
                Text("Tap to explore")
                    .font(.caption2).foregroundStyle(textColor.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Galaxy Explorer")
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(textColor.opacity(0.85))
            Spacer(minLength: 2)
            Text(value).fontWeight(.medium)
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}
