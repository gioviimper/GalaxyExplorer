import SwiftUI

struct ContentView: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    // MARK: - Future content API integration
    // TODO(API): Add a dedicated content service and an observable view model here.
    // Confirm the provider, endpoint, authentication, response schema, and usage terms.
    // Map API responses to app-owned models instead of exposing raw JSON to the UI.
    // Start loading from a cancellable SwiftUI .task; never fetch inside body or layout.
    // Publish content changes on the main actor and pass card data into Mars3DView.
    // Keep the bundled facts and card content available on first launch without a network.
    // Persist the last successful response with its source URL, units, and update date.
    // On timeout, decoding failure, or no connection, retain cached or bundled content.
    // Keep loading, empty, and error messages in English; preserve planet interaction.

    var body: some View {
        GeometryReader { geometry in
            if typeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        planet.frame(height: max(440, geometry.size.height * 0.65))
                    }
                }
            } else if geometry.size.width > geometry.size.height {
                HStack(spacing: 0) {
                    header.frame(width: min(320, geometry.size.width * 0.42))
                    planet
                }
            } else {
                VStack(spacing: 0) {
                    header
                    planet
                }
            }
        }
        .foregroundStyle(.white)
        .background(.black)
        .preferredColorScheme(.dark)
    }

    private var planet: some View {
        Mars3DView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SOLAR SYSTEM · 04")
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(.orange)
            Text("Mars")
                .font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) { facts }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) { facts }
                    VStack(alignment: .leading, spacing: 12) { facts }
                }
            }
            Text("Drag to rotate · Pinch to zoom")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: 700, alignment: .leading)
    }

    // TODO(API): Bind these values to validated view-model fields when supported by
    // the chosen provider. Keep units explicit; distinguish average from live data.
    // News or image endpoints may not supply gravity, temperature, or composition.
    @ViewBuilder private var facts: some View {
        fact("Gravity", "≈ 3.7 m/s²")
        fact("Avg. temperature", "−65 °C")
        fact("Composition", "Rock and dust")
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.75))
            Text(value).font(.body.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Mars Explorer") { ContentView() }
