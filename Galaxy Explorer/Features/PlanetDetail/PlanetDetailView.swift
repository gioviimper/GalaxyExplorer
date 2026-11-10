import SwiftUI

struct PlanetDetailView: View {
    // The selected configuration drives both the header and the shared 3D scene.
    let planet: Planet
    @State private var information: PlanetInformation?
    @State private var viewRequest: PlanetViewRequest?
    @AppStorage("hapticFeedbackEnabled") private var hapticsEnabled = true

    init(planet: Planet = .mars) {
        self.planet = planet
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    // MARK: - Future content API integration
    // TODO(API): Add a dedicated content service and an observable view model here.
    // Confirm the provider, endpoint, authentication, response schema, and usage terms.
    // Map API responses to app-owned models instead of exposing raw JSON to the UI.
    // Start loading from a cancellable SwiftUI .task; never fetch inside body or layout.
    // Publish content changes on the main actor and pass card data into Planet3DView.
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
                        planetView.frame(height: max(440, geometry.size.height * 0.65))
                    }
                }
            } else if geometry.size.width > geometry.size.height {
                HStack(spacing: 0) {
                    ScrollView { header }
                        .frame(width: min(320, geometry.size.width * 0.42))
                    planetView
                }
            } else {
                VStack(spacing: 0) {
                    header
                    planetView
                }
            }
        }
        .foregroundStyle(.white)
        .background(.black)
        .preferredColorScheme(.dark)
        .sheet(item: $information) { item in
            PlanetInformationView(information: item)
                .preferredColorScheme(.dark)
        }
    }

    private var planetView: some View {
        Planet3DView(
            planet: planet, hapticsEnabled: hapticsEnabled,
            isInteractionEnabled: information == nil, request: viewRequest,
            onCardSelected: { information = $0 }
        )
        // A different planet gets fresh card IDs, camera state and sensor ownership.
        .id(planet)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(planet.systemLabel)
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(.orange)
                Spacer(minLength: 8)
                Menu {
                    ForEach(PlanetViewAction.allCases) { action in
                        Button {
                            viewRequest = PlanetViewRequest(action: action)
                        } label: {
                            Label(action.title, systemImage: action.symbol)
                        }
                    }
                    Divider()
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("View controls")
                .accessibilityHint("Rotate, zoom, reset the view, or change haptic feedback")
            }
            Text(planet.name)
                .font(.largeTitle.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            // The Sun and every planet use the same information layout.
            PlanetFactsView(planet: planet)
            Text("Drag to rotate · Pinch to zoom")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: 700, alignment: .leading)
    }
}

#Preview("Mars Explorer") { PlanetDetailView() }

#Preview("Venus Explorer") { PlanetDetailView(planet: .venus) }

#Preview("Saturn Explorer") { PlanetDetailView(planet: .saturn) }

#Preview("Sun Explorer") { PlanetDetailView(planet: .sun) }

#Preview("Sun - Accessibility Text") {
    PlanetDetailView(planet: .sun).environment(\.dynamicTypeSize, .accessibility3)
}
