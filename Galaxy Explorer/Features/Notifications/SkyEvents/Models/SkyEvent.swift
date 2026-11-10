import Foundation

// All dates are absolute instants. Views format them in the user's current time zone.
struct SkyEvent: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let startsAt: Date
    let endsAt: Date
    let sourceURL: URL
    let calculationURL: URL?
    let kind: Kind
    let visibility: Visibility
    enum Kind: String, Codable { case meteorShower, solarEclipse, lunarEclipse, fullMoon, blueMoon }
    enum Visibility: String, Codable { case locallyVerified }
}
