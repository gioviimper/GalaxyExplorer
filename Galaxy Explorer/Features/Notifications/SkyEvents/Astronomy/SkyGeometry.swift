import Foundation

// Low precision solar coordinates are used only for darkness screening, with wide margins.
// Eclipse geometry and lunar transit elevations come from IMCCE's INPOP ephemerides.
// Sidereal time: USNO https://aa.usno.navy.mil/faq/GAST
// Solar coordinates: https://aa.usno.navy.mil/faq/sun_approx
// Meteor radiant screening uses a conservative 20-degree elevation threshold.
enum SkyGeometry {
    private static let radians = Double.pi / 180
    static func altitude(raHours: Double, declination: Double, at date: Date, observer: SkyObserver) -> Double
    {
        let jd = date.timeIntervalSince1970 / 86400 + 2440587.5
        let t = (jd - 2_451_545) / 36525
        let sidereal = 280.46061837 + 360.98564736629 * (jd - 2_451_545) + 0.000387933 * t * t
        let hourAngle =
            (sidereal + observer.longitude - raHours * 15).truncatingRemainder(dividingBy: 360) * radians
        let lat = observer.latitude * radians
        let dec = declination * radians
        let sine = sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(hourAngle)
        return asin(min(1, max(-1, sine))) / radians
    }
    static func sunAltitude(at date: Date, observer: SkyObserver) -> Double {
        let d = date.timeIntervalSince1970 / 86400 + 2440587.5 - 2_451_545
        let g = (357.529 + 0.98560028 * d) * radians
        let longitude = (280.459 + 0.98564736 * d + 1.915 * sin(g) + 0.020 * sin(2 * g)) * radians
        let obliquity = (23.439 - 0.00000036 * d) * radians
        let ra = atan2(cos(obliquity) * sin(longitude), cos(longitude)) / radians / 15
        let dec = asin(sin(obliquity) * sin(longitude)) / radians
        return altitude(raHours: ra, declination: dec, at: date, observer: observer)
    }
    static func date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        let utc = value.hasSuffix("Z") ? value : value + "Z"
        if let result = formatter.date(from: utc) { return result }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: utc)
    }
}
