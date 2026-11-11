import Foundation

// Stable scene slots stay separate from NASA's media identifiers.
nonisolated struct PlanetCardContent: Codable, Equatable, Sendable, Identifiable {
    let id: String
    var nasaID: String? = nil
    var title: String? = nil
    var summary: String? = nil
    var detail: String? = nil
    var imageURL: URL? = nil
    var sourceURL: URL? = nil
    var credit: String? = nil

    static let slotCount = 14
    static func emptySlots(for planetID: String) -> [Self] {
        (1...slotCount).map { Self(id: String(format: "%@-card-%02d", planetID, $0)) }
    }
}

nonisolated struct PlanetContentQuery: Sendable {
    let planetID: String
    let searchTerm: String
}

nonisolated struct PlanetContentSnapshot: Codable, Sendable {
    let version: Int
    let planetID: String
    let fetchedAt: Date
    let cards: [PlanetCardContent]
}
