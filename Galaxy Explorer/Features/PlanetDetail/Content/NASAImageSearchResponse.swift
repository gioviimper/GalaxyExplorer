import Foundation

// NASA Image and Video Library search metadata, not the unrelated sky-event calendar.
// API documentation: https://images.nasa.gov/docs/images.nasa.gov_api_docs.pdf
nonisolated struct NASAImageSearchResponse: Decodable {
    let collection: Collection
    struct Collection: Decodable, Sendable { let items: [Item] }
    struct Item: Decodable, Sendable {
        let data: [Metadata]
        let links: [Link]?
    }
    struct Link: Decodable, Sendable {
        let href: String
        let rel: String?
        let render: String?
    }
    struct Metadata: Decodable, Sendable {
        let nasaID: String
        let title: String
        let description: String?
        let dateCreated: String?
        let secondaryCreator: String?
        let center: String?
        let keywords: [String]?
        enum CodingKeys: String, CodingKey {
            case nasaID = "nasa_id"
            case title, description
            case dateCreated = "date_created"
            case secondaryCreator = "secondary_creator"
            case keywords, center
        }
    }
}
