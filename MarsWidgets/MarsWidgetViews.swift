import SwiftUI
import WidgetKit

// The Home widgets share the same artwork and adapt to their available space.
private struct WidgetStarfield: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(red: 0.015, green: 0.02, blue: 0.035)
                ForEach(0..<28, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(index.isMultiple(of: 5) ? 0.65 : 0.22))
                        .frame(width: index.isMultiple(of: 5) ? 1.5 : 0.8,
                               height: index.isMultiple(of: 5) ? 1.5 : 0.8)
                        .position(x: CGFloat((index * 67 + 19) % 101) / 100 * geometry.size.width,
                                  y: CGFloat((index * 43 + 31) % 97) / 96 * geometry.size.height)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct MarsWidgetsEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MarsEntry

    var body: some View {
        Group {
            if family == .systemSmall { smallWidget } else { mediumWidget }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { WidgetStarfield() }
    }

    private var planet: some View {
        Image(uiImage: MarsWidgetArtwork.image)
            .resizable()
            .widgetAccentedRenderingMode(.fullColor)
            .scaledToFit()
            .accessibilityLabel("Mars")
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Mars").font(.headline)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.orange)
            }
            planet.frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("Explore the red planet")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Galaxy Explorer")
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            planet.frame(maxWidth: 110, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Mars").font(.title2.weight(.semibold))
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.orange)
                }
                fact("Gravity", entry.gravity)
                fact("Avg. temp.", entry.temperature)
                Text("Tap to explore")
                    .font(.caption2).foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Galaxy Explorer")
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(.white.opacity(0.75))
            Spacer(minLength: 2)
            Text(value).fontWeight(.medium)
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

