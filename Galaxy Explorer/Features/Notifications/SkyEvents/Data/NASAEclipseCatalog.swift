import Foundation

// Reject changed NASA markup instead of scheduling unverified eclipse dates.
enum NASAEclipseCatalog {
    static func dates(in html: String) throws -> Set<String> {
        let text = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let expression = try NSRegularExpression(
            pattern:
                "(20[0-9]{2})\\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+([0-9]{2})\\s+[0-9]{2}:[0-9]{2}:[0-9]{2}"
        )
        let ns = text as NSString
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let dates = Set(
            expression.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
                match -> String? in
                guard let index = months.firstIndex(of: ns.substring(with: match.range(at: 2))) else {
                    return nil
                }
                return ns.substring(with: match.range(at: 1)) + String(format: "-%02d-", index + 1)
                    + ns.substring(with: match.range(at: 3))
            })
        guard dates.count > 100 else { throw SkyCalendarError.changedFormat("NASA eclipse catalog") }
        return dates
    }
}
