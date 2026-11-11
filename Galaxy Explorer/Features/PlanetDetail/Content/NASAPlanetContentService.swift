import Foundation

// The actor keeps disk access and shared requests out of SceneKit's frame callbacks.
actor NASAPlanetContentService {
    static let shared = NASAPlanetContentService()
    private let maxAge: TimeInterval = 86400
    private let cacheDirectory: URL
    private let session: URLSession
    private var inFlight: [String: Task<PlanetContentSnapshot, Error>] = [:]

    init(cacheDirectory: URL? = nil, session: URLSession = .shared) {
        self.cacheDirectory =
            cacheDirectory
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("nasa-planet-cards-v1", isDirectory: true)
        self.session = session
    }

    func cached(for query: PlanetContentQuery) -> PlanetContentSnapshot? {
        guard let url = cacheURL(for: query.planetID), let data = try? Data(contentsOf: url),
            let snapshot = try? JSONDecoder().decode(PlanetContentSnapshot.self, from: data),
            snapshot.version == 1, snapshot.planetID == query.planetID,
            snapshot.cards.map(\.id) == PlanetCardContent.emptySlots(for: query.planetID).map(\.id)
        else { return nil }
        return snapshot
    }

    func refreshIfNeeded(for query: PlanetContentQuery, force: Bool = false) async throws
        -> PlanetContentSnapshot
    {
        if !force, let cached = cached(for: query) {
            let age = Date.now.timeIntervalSince(cached.fetchedAt)
            if age >= 0 && age < maxAge { return cached }
        }
        if let running = inFlight[query.planetID] { return try await running.value }
        let task = Task { try await fetch(query) }
        inFlight[query.planetID] = task
        defer { inFlight[query.planetID] = nil }
        return try await task.value
    }

    private func fetch(_ query: PlanetContentQuery) async throws -> PlanetContentSnapshot {
        guard let cacheURL = cacheURL(for: query.planetID) else { throw URLError(.badURL) }
        var components = URLComponents(string: "https://images-api.nasa.gov/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query.searchTerm),
            URLQueryItem(name: "media_type", value: "image"), URLQueryItem(name: "page_size", value: "60"),
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
            data.count <= 5_000_000
        else { throw URLError(.badServerResponse) }
        let cards = try NASAPlanetContentMapper.cards(from: data, planetID: query.planetID)
        guard cards.contains(where: { $0.nasaID != nil }) else { throw URLError(.zeroByteResource) }
        let snapshot = PlanetContentSnapshot(
            version: 1, planetID: query.planetID, fetchedAt: .now, cards: cards)
        // A full disk must not prevent newly fetched content from being displayed.
        if let data = try? JSONEncoder().encode(snapshot) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try? data.write(to: cacheURL, options: .atomic)
        }
        return snapshot
    }

    private func cacheURL(for planetID: String) -> URL? {
        guard
            ["sun", "mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"].contains(
                planetID)
        else { return nil }
        return cacheDirectory.appendingPathComponent(planetID + ".json")
    }
}
