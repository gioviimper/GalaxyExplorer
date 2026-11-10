import Foundation

// Only published dates and independently screened local circumstances become alerts.
// No API key is needed for these public NASA and IMCCE endpoints.
@MainActor
final class SkyCalendarClient {
    struct Batch {
        var events: [SkyEvent]
        var warnings: [String]
    }
    private let session: URLSession
    private var cache: [URL: (Date, Data)] = [:]
    private let base = "https://opale.imcce.fr/api/v1/phenomena/"
    private let solarSource = URL(string: "https://eclipse.gsfc.nasa.gov/SEcat5/SE2001-2100.html")!
    private let lunarSource = URL(string: "https://eclipse.gsfc.nasa.gov/LEcat5/LE2001-2100.html")!

    init() {
        // Observer coordinates are not written to an HTTP disk cache.
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 45
        session = URLSession(configuration: config)
    }

    private func download(_ url: URL) async throws -> Data {
        try Task.checkCancellation()
        if let (date, data) = cache[url], Date.now.timeIntervalSince(date) < 86400 { return data }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count < 8_000_000 else {
            throw SkyCalendarError.unavailable(url.host ?? "event service")
        }
        if cache.values.reduce(0, { $0 + $1.1.count }) + data.count > 12_000_000 { cache.removeAll() }
        cache[url] = (.now, data)
        return data
    }

    func fetch(observer: SkyObserver, now: Date = .now) async throws -> Batch {
        guard observer.isValid else { throw SkyCalendarError.unavailable("location") }
        let until = now.addingTimeInterval(180 * 86400)
        let calendar = Calendar.current
        let years = Set([calendar.component(.year, from: now), calendar.component(.year, from: until)])
            .sorted()
        var batch = Batch(events: [], warnings: [])
        async let meteors = download(NASAMeteorCalendar.source)
        async let solar = download(solarSource)
        async let lunar = download(lunarSource)
        var solarDates = Set<String>()
        var lunarDates = Set<String>()
        do {
            let html = String(decoding: try await meteors, as: UTF8.self)
            batch.events += try NASAMeteorCalendar.events(
                in: html, observer: observer, now: now, until: until)
        } catch {
            batch.warnings.append("NASA meteor dates could not be updated. Meteor alerts were skipped.")
        }
        do {
            solarDates = try NASAEclipseCatalog.dates(in: String(decoding: try await solar, as: UTF8.self))
        } catch {
            batch.warnings.append(
                "NASA solar eclipse dates could not be verified. Solar alerts were skipped.")
        }
        do {
            lunarDates = try NASAEclipseCatalog.dates(in: String(decoding: try await lunar, as: UTF8.self))
        } catch {
            batch.warnings.append(
                "NASA lunar eclipse dates could not be verified. Lunar eclipse alerts were skipped.")
        }
        var fullMoons: [Date] = []
        for year in years {
            try Task.checkCancellation()
            if !solarDates.isEmpty {
                do {
                    var components = URLComponents(string: base + "eclipses/10/\(year)")!
                    components.queryItems = [URLQueryItem(name: "observer", value: observer.parameter)]
                    let decoded = try JSONDecoder().decode(
                        IMCCEResponses.EclipseEnvelope.self, from: await download(components.url!))
                    guard decoded.response.timescale == "UTC", let actual = decoded.request?.observer,
                        actual.count >= 2, abs(actual[0] - observer.latitude) < 0.001,
                        abs(actual[1] - observer.longitude) < 0.001
                    else { throw SkyCalendarError.changedFormat("IMCCE") }
                    batch.events += LocalSkyEventBuilder.solarEvents(
                        decoded.response.data ?? [], nasaDates: solarDates, source: solarSource)
                } catch {
                    batch.warnings.append("Local solar eclipse calculations are unavailable for \(year).")
                }
            }
            if !lunarDates.isEmpty {
                do {
                    let url = URL(string: base + "eclipses/301/\(year)")!
                    let decoded = try JSONDecoder().decode(
                        IMCCEResponses.EclipseEnvelope.self, from: await download(url))
                    guard decoded.response.timescale == "UTC" else {
                        throw SkyCalendarError.changedFormat("IMCCE")
                    }
                    batch.events += LocalSkyEventBuilder.lunarEvents(
                        decoded.response.lunareclipse ?? [], observer: observer,
                        nasaDates: lunarDates, source: lunarSource)
                } catch { batch.warnings.append("Lunar eclipse calculations are unavailable for \(year).") }
            }
            do {
                let url = URL(string: base + "moonphases?year=\(year)")!
                let decoded = try JSONDecoder().decode(
                    IMCCEResponses.PhaseEnvelope.self, from: await download(url))
                guard decoded.response.timescale == "UTC" else {
                    throw SkyCalendarError.changedFormat("IMCCE")
                }
                fullMoons += decoded.response.data.filter { $0.moonPhase == "FullMoon" }.compactMap {
                    SkyGeometry.date($0.date)
                }
            } catch { batch.warnings.append("Moon phases are unavailable for \(year).") }
        }
        if !fullMoons.isEmpty {
            do {
                let day = String(ISO8601DateFormatter().string(from: now).prefix(10))
                let url = URL(string: base + "rts/301/\(day)/\(observer.parameter)?nbd=182")!
                let decoded = try JSONDecoder().decode(
                    IMCCEResponses.TransitEnvelope.self, from: await download(url))
                guard decoded.response.timescale == "UTC" else {
                    throw SkyCalendarError.changedFormat("IMCCE")
                }
                batch.events += LocalSkyEventBuilder.moonEvents(
                    fullMoons, transits: decoded.response.data.flatMap { $0["301"] ?? [] },
                    observer: observer, calculationURL: url, calendar: calendar)
            } catch {
                batch.warnings.append("Local Moon visibility is unavailable. Moon alerts were skipped.")
            }
        }
        try Task.checkCancellation()
        if batch.events.isEmpty && batch.warnings.count >= 3 {
            throw SkyCalendarError.unavailable(
                "astronomical sources; previously verified alerts are unchanged")
        }
        // Leave space for fact notifications within iOS's pending request budget.
        let unique = Dictionary(batch.events.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        batch.events = LocalSkyEventBuilder.removingDuplicateMoonAlerts(Array(unique.values)).filter {
            $0.startsAt > now.addingTimeInterval(3600) && $0.startsAt < until
        }
        .sorted { $0.startsAt < $1.startsAt }.prefix(24).map { $0 }
        return batch
    }
}
