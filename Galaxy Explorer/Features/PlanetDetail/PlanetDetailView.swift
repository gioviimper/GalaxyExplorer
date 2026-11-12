import SwiftUI

struct PlanetDetailView: View {
    // The selected configuration drives both the header and the shared 3D scene.
    let planet: Planet
    @State private var information: PlanetInformation?
    @State private var selectedCardID: String?
    @State private var cardPresentationTask: Task<Void, Never>?
    @StateObject private var content = PlanetContentViewModel()
    @State private var viewRequest: PlanetViewRequest?
    @AppStorage("hapticFeedbackEnabled") private var hapticsEnabled = true

    init(planet: Planet = .mars) {
        self.planet = planet
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    // Loading belongs to SwiftUI; gesture and frame callbacks never fetch NASA data.
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
        .task(id: planet.id) { await content.load(for: planet) }
        .onChange(of: content.cards) { _, cards in
            guard let selected = information, let card = cards.first(where: { $0.id == selected.id }) else {
                return
            }
            information = PlanetInformation(
                id: card.id, planetName: planet.name,
                title: card.title, summary: card.summary, detail: card.detail,
                imageURL: card.imageURL, sourceURL: card.sourceURL, credit: card.credit)
        }
        .foregroundStyle(.white)
        .background(.black)
        .preferredColorScheme(.dark)
        .onDisappear {
            cardPresentationTask?.cancel()
            cardPresentationTask = nil
            selectedCardID = nil
        }
        .sheet(item: $information, onDismiss: { selectedCardID = nil }) { item in
            PlanetInformationSheet(information: item)
                .preferredColorScheme(.dark)
        }
    }

    private var planetView: some View {
        Planet3DView(
            planet: planet, cardContents: content.cards, selectedCardID: selectedCardID,
            hapticsEnabled: hapticsEnabled,
            isInteractionEnabled: information == nil && cardPresentationTask == nil, request: viewRequest,
            onCardSelected: { selected in
                cardPresentationTask?.cancel()
                selectedCardID = selected.id
                cardPresentationTask = Task { @MainActor in
                    // Let the touch feedback appear before the glass panel covers the selected card.
                    do {
                        try await Task.sleep(for: .milliseconds(160))
                    } catch {
                        return
                    }
                    guard !Task.isCancelled else { return }
                    information = selected
                    cardPresentationTask = nil
                }
            }
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
            if content.isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading NASA content…").font(.caption)
                }
                .accessibilityElement(children: .combine)
            }
            if let status = content.status {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
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
