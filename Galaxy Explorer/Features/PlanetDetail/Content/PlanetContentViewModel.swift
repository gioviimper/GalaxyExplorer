import Combine
import Foundation

// SwiftUI owns loading; the coordinator only receives already decoded card values.
@MainActor
final class PlanetContentViewModel: ObservableObject {
    @Published private(set) var cards: [PlanetCardContent] = []
    @Published private(set) var isLoading = false
    @Published private(set) var status: String?
    private var generation = UUID()

    func load(for planet: Planet, force: Bool = false) async {
        let generation = UUID()
        self.generation = generation
        let query = PlanetContentQuery(
            planetID: planet.id,
            searchTerm: planet.id == "mars"
                ? "Mars surface" : (planet.kind == .star ? "Sun solar" : "\(planet.name) planet"))
        let service = NASAPlanetContentService.shared
        if cards.first?.id.hasPrefix(planet.id + "-card-") != true {
            cards = PlanetCardContent.emptySlots(for: planet.id)
        }
        isLoading = true
        status = nil
        if let cached = await service.cached(for: query) {
            guard !Task.isCancelled, self.generation == generation else { return }
            cards = cached.cards
        }
        do {
            let snapshot = try await service.refreshIfNeeded(for: query, force: force)
            guard !Task.isCancelled, self.generation == generation else { return }
            cards = snapshot.cards
            isLoading = false
        } catch {
            guard !Task.isCancelled, self.generation == generation else { return }
            isLoading = false
            status =
                cards.contains(where: { $0.title != nil })
                ? "Showing saved NASA content. The latest update is unavailable."
                : "NASA content is unavailable. You can still explore the planet."
        }
    }
}
