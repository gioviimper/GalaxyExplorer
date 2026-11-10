import SwiftUI

// I keep three equal columns for every body, including the Sun.
struct PlanetFactsView: View {
    let planet: Planet
    @Environment(\.dynamicTypeSize) private var typeSize
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 16, alignment: .topLeading), count: 3)

    private var referenceLabels: [String] { ["Gravity", "Composition"] + Planet.all.map(\.temperatureLabel) }

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) { facts }
        } else {
            // Long content wraps inside its column instead of switching the whole panel to a list.
            LazyVGrid(columns: columns, alignment: .leading, spacing: 0) { facts }
        }
    }

    // NASA API CONTENT GOES HERE: Use validated, cached fields for the selected body.
    // Keep the Sun's temperature labelled as a surface value, never a core measurement.
    @ViewBuilder private var facts: some View {
        fact(
            "Gravity", planet.gravity,
            labels: referenceLabels, values: Planet.all.map(\.gravity))
        fact(
            planet.temperatureLabel, planet.temperature,
            labels: referenceLabels, values: Planet.all.map(\.temperature))
        fact(
            "Composition", planet.composition,
            labels: referenceLabels, values: Planet.all.map(\.composition))
    }

    private func fact(_ label: String, _ value: String, labels: [String], values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sizedText(label, reserving: labels)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            sizedText(value, reserving: values)
                .font(.body.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func sizedText(_ value: String, reserving referenceValues: [String]) -> some View {
        ZStack(alignment: .topLeading) {
            if !typeSize.isAccessibilitySize {
                // Reserve the same text height across selections without shrinking or clipping text.
                // These invisible measurements never become VoiceOver content.
                ForEach(Array(Set(referenceValues)).sorted(), id: \.self) { reference in
                    Text(reference)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .accessibilityHidden(true)
                }
            }
            Text(value).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
