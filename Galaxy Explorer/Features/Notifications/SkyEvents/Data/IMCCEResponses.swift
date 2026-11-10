import Foundation

// Decoding types mirror IMCCE responses; views use SkyEvent instead.
enum IMCCEResponses {
    struct EclipseEnvelope: Decodable {
        let request: Request?
        let response: Response
        struct Request: Decodable { let observer: [Double]? }
        struct Response: Decodable {
            let timescale: String
            let data: [Eclipse]?
            let lunareclipse: [Eclipse]?
        }
    }
    struct Eclipse: Decodable {
        let calendarDate: String
        let type: String
        let magnitude: Double?
        let events: [String: Contact]
        let link: Links?
    }
    struct Contact: Decodable {
        let date: String
        let Sun: Body?
        let Moon: Body?
    }
    struct Body: Decodable {
        let RA: Double?
        let DEC: Double?
        let parallax: Double?
        let elevation: Double?
    }
    struct Links: Decodable {
        let selfURL: URL?
        enum CodingKeys: String, CodingKey { case selfURL = "self" }
    }
    struct PhaseEnvelope: Decodable {
        let response: Response
        struct Response: Decodable {
            let timescale: String
            let data: [Phase]
        }
        struct Phase: Decodable {
            let date: String
            let moonPhase: String
        }
    }
    struct TransitEnvelope: Decodable {
        let response: Response
        struct Response: Decodable {
            let timescale: String
            let data: [[String: [MoonTransit]]]
        }
    }
    struct MoonTransit: Decodable { let upperTransit: [TransitPoint] }
    struct TransitPoint: Decodable {
        let coord: Double
        let date: String
    }
}
