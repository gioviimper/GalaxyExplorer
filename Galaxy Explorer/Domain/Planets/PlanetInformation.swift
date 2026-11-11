import Foundation

// Optional editorial content for one stable surface card.
struct PlanetInformation: Identifiable {
    let id: String
    let planetName: String
    let title: String?
    let summary: String?
    let detail: String?
    var imageURL: URL? = nil
    var sourceURL: URL? = nil
    var credit: String? = nil
}
