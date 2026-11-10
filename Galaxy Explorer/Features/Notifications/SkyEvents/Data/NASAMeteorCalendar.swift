import Foundation

// NASA publishes an editorial calendar, not a meteor forecast API. Parse only explicitly
// dated peak nights, never silently repeat last year's dates when the page changes.
enum NASAMeteorCalendar {
    static let source = URL(
        string: "https://science.nasa.gov/solar-system/meteors-meteorites/meteor-showers/")!
    // Approximate peak radiants in hours/degrees, for broad horizon screening only.
    // Reference: IAU Meteor Data Center https://www.ta3.sk/IAUC22DB/MDC2022/
    private static let radiants: [(String, Double, Double)] = [
        ("Quadrantids", 15.3, 49), ("Lyrids", 18.1, 34), ("Eta Aquariids", 22.3, -1),
        ("Southern Delta Aquariids", 22.7, -16), ("Perseids", 3.2, 58),
        ("Orionids", 6.3, 16), ("Leonids", 10.2, 22), ("Geminids", 7.5, 33),
    ]
    struct Peak {
        let name: String
        let year: Int
        let month: Int
        let day: Int
        let ra: Double
        let dec: Double
    }

    static func peaks(in html: String) throws -> [Peak] {
        var peaks: [Peak] = []
        for (name, ra, dec) in radiants {
            let escaped = NSRegularExpression.escapedPattern(for: name)
            guard
                let heading = html.range(
                    of: "(?s)>" + escaped + "</h3>.*?<p[^>]*>(.*?)</p>", options: .regularExpression)
            else { continue }
            let text = String(html[heading]).replacingOccurrences(
                of: "<[^>]+>", with: " ", options: .regularExpression
            )
            .replacingOccurrences(of: "&ndash;", with: "-").replacingOccurrences(of: "&#8211;", with: "-")
            let expression = try NSRegularExpression(
                pattern: "Peak night:\\s*([A-Za-z.]+)\\s+(\\d{1,2})\\s*[-–]\\s*\\d{1,2}(?:,\\s*(20\\d{2}))?")
            let ns = text as NSString
            guard let match = expression.firstMatch(in: text, range: NSRange(location: 0, length: ns.length))
            else { continue }
            let years = try NSRegularExpression(pattern: "20\\d{2}").matches(
                in: text, range: NSRange(location: 0, length: ns.length))
            guard let lastYear = years.last, let year = Int(ns.substring(with: lastYear.range)),
                let day = Int(ns.substring(with: match.range(at: 2)))
            else { continue }
            let monthName = String(ns.substring(with: match.range(at: 1)).prefix(3)).lowercased()
            guard
                let index = [
                    "jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec",
                ].firstIndex(of: monthName)
            else { continue }
            peaks.append(Peak(name: name, year: year, month: index + 1, day: day, ra: ra, dec: dec))
        }
        guard !peaks.isEmpty else { throw SkyCalendarError.changedFormat("NASA meteor calendar") }
        return peaks
    }

    static func events(
        in html: String, observer: SkyObserver, now: Date, until: Date, calendar: Calendar = .current
    ) throws -> [SkyEvent] {
        try peaks(in: html).compactMap { peak in
            guard
                let noon = calendar.date(
                    from: DateComponents(year: peak.year, month: peak.month, day: peak.day, hour: 12)),
                let nextNoon = calendar.date(byAdding: .day, value: 1, to: noon), noon < until, nextNoon > now
            else { return nil }
            var best: (Date, Double)?
            // Screen the actual NASA peak night. Do not assume every latitude has darkness.
            for step in 0..<48 {
                let date = noon.addingTimeInterval(Double(step) * 1800)
                guard date < nextNoon, date > now,
                    SkyGeometry.sunAltitude(at: date, observer: observer) < -12
                else { continue }
                let altitude = SkyGeometry.altitude(
                    raHours: peak.ra, declination: peak.dec, at: date, observer: observer)
                if altitude > 20 && altitude > (best?.1 ?? -90) { best = (date, altitude) }
            }
            guard let best else { return nil }
            return SkyEvent(
                id: "meteor-\(peak.name)-\(peak.year)", title: "\(peak.name) meteor shower",
                summary:
                    "NASA lists this peak night. The radiant is estimated to be above your horizon during darkness. Clouds, moonlight and light pollution can reduce visibility.",
                startsAt: best.0, endsAt: nextNoon, sourceURL: source, calculationURL: nil,
                kind: .meteorShower, visibility: .locallyVerified)
        }
    }
}
