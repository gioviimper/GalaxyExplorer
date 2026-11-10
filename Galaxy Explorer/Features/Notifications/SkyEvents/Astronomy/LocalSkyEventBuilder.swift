import Foundation

// Converts validated source data into conservative local viewing opportunities.
enum LocalSkyEventBuilder {
    // An eclipse and its full Moon are one observing occasion, so send one alert.
    static func removingDuplicateMoonAlerts(_ events: [SkyEvent]) -> [SkyEvent] {
        let eclipses = events.filter { $0.kind == .lunarEclipse }
        return events.filter { event in
            guard event.kind == .fullMoon || event.kind == .blueMoon else { return true }
            return !eclipses.contains { abs($0.startsAt.timeIntervalSince(event.startsAt)) < 24 * 3600 }
        }
    }

    static func solarEvents(_ eclipses: [IMCCEResponses.Eclipse], nasaDates: Set<String>, source: URL)
        -> [SkyEvent]
    {
        eclipses.compactMap { eclipse in
            guard nasaDates.contains(eclipse.calendarDate), (eclipse.magnitude ?? 0) > 0,
                eclipse.type.hasPrefix("Observer"), let greatest = eclipse.events["greatest"],
                let elevation = greatest.Sun?.elevation, elevation > 5,
                let date = SkyGeometry.date(greatest.date)
            else { return nil }
            return SkyEvent(
                id: "solar-\(eclipse.calendarDate)", title: "Solar eclipse",
                summary:
                    "An eclipse is above the horizon near your saved location. Local maximum is shown. Use certified solar viewing protection; never look directly at the Sun.",
                startsAt: date, endsAt: SkyGeometry.date(eclipse.events["P4"]?.date ?? "") ?? date,
                sourceURL: source, calculationURL: eclipse.link?.selfURL, kind: .solarEclipse,
                visibility: .locallyVerified)
        }
    }

    static func lunarEvents(
        _ eclipses: [IMCCEResponses.Eclipse], observer: SkyObserver, nasaDates: Set<String>, source: URL
    ) -> [SkyEvent] {
        eclipses.compactMap { eclipse in
            guard nasaDates.contains(eclipse.calendarDate) else { return nil }
            // Screen contact/maximum instants with a 5-degree margin and parallax correction.
            // Conservative selection may omit grazing horizon events rather than send a false alert.
            let candidates = eclipse.events.compactMap { key, event -> (String, Date, Double)? in
                guard let moon = event.Moon, let ra = moon.RA, let dec = moon.DEC,
                    let date = SkyGeometry.date(event.date)
                else { return nil }
                let altitude =
                    SkyGeometry.altitude(raHours: ra, declination: dec, at: date, observer: observer)
                    - (moon.parallax ?? 1.1)
                guard altitude > 5, SkyGeometry.sunAltitude(at: date, observer: observer) < 0 else {
                    return nil
                }
                return (key, date, altitude)
            }
            guard let best = candidates.max(by: { $0.2 < $1.2 }) else { return nil }
            let totalStart = SkyGeometry.date(eclipse.events["U2"]?.date ?? "")
            let totalEnd = SkyGeometry.date(eclipse.events["U3"]?.date ?? "")
            let seesTotality =
                totalStart.map { start in totalEnd.map { end in best.1 >= start && best.1 <= end } ?? false }
                ?? false
            return SkyEvent(
                id: "lunar-\(eclipse.calendarDate)",
                title: seesTotality ? "Total lunar eclipse · Blood Moon" : "Lunar eclipse",
                summary:
                    "Part of this eclipse is above your horizon. The listed time is a locally observable phase; other phases may occur below the horizon. Clear skies are still needed.",
                startsAt: best.1, endsAt: SkyGeometry.date(eclipse.events["P2"]?.date ?? "") ?? best.1,
                sourceURL: source, calculationURL: eclipse.link?.selfURL, kind: .lunarEclipse,
                visibility: .locallyVerified)
        }
    }

    static func moonEvents(
        _ fullMoons: [Date], transits: [IMCCEResponses.MoonTransit], observer: SkyObserver,
        calculationURL: URL, calendar: Calendar
    ) -> [SkyEvent] {
        let sorted = fullMoons.sorted()
        return sorted.compactMap { phase in
            let isBlue = sorted.contains {
                $0 < phase && calendar.isDate($0, equalTo: phase, toGranularity: .month)
            }
            let candidates = transits.flatMap(\.upperTransit).compactMap { point -> Date? in
                guard point.coord > 5, let date = SkyGeometry.date(point.date),
                    abs(date.timeIntervalSince(phase)) < 18 * 3600,
                    SkyGeometry.sunAltitude(at: date, observer: observer) < -6
                else { return nil }
                return date
            }
            guard
                let date = candidates.min(by: {
                    abs($0.timeIntervalSince(phase)) < abs($1.timeIntervalSince(phase))
                })
            else { return nil }
            return SkyEvent(
                id: "moon-\(Int(phase.timeIntervalSince1970))", title: isBlue ? "Blue Moon" : "Full Moon",
                summary: isBlue
                    ? "The second full Moon in your local calendar month. Blue Moon is a calendar name; the Moon does not turn blue. The listed time is a local viewing opportunity."
                    : "The Moon is near its full phase and above your horizon during darkness. The listed time is a local viewing opportunity, not the exact full-phase instant.",
                startsAt: date, endsAt: date.addingTimeInterval(3600),
                sourceURL: URL(string: "https://science.nasa.gov/moon/facts/")!,
                calculationURL: calculationURL,
                kind: isBlue ? .blueMoon : .fullMoon, visibility: .locallyVerified)
        }
    }
}
