import Foundation
import UserNotifications

// Only the fact category is replaced; sky event requests are owned separately.
@MainActor
final class PlanetFactNotificationScheduler {
    private let center = UNUserNotificationCenter.current()
    private var updateTask: Task<Void, Never>?
    private let prefix = "planet-fact-"

    func reschedule(authorization: UNAuthorizationStatus, onError: @escaping (String) -> Void) {
        let previous = updateTask
        previous?.cancel()
        updateTask = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            guard UserDefaults.standard.bool(forKey: "planetFactsEnabled"),
                authorization == .authorized || authorization == .provisional
            else { return }
            let defaults = UserDefaults.standard
            let interval = max(1, defaults.integer(forKey: "planetFactInterval"))
            let hour = defaults.object(forKey: "planetFactHour") as? Int ?? 19
            let minute = defaults.integer(forKey: "planetFactMinute")
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            let origin = defaults.object(forKey: "planetFactOrigin") as? Date ?? today
            defaults.set(origin, forKey: "planetFactOrigin")
            let elapsed = calendar.dateComponents([.day], from: origin, to: today).day ?? 0
            var count = 0
            for offset in 0..<60 {
                guard !Task.isCancelled else { return }
                let day = elapsed + offset
                guard day >= 0, day.isMultiple(of: interval), count < 32,
                    let date = calendar.date(byAdding: .day, value: offset, to: today),
                    let delivery = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date),
                    delivery > .now
                else { continue }
                let fact = PlanetNotificationFact.all[(day / interval) % PlanetNotificationFact.all.count]
                let content = UNMutableNotificationContent()
                content.title = "Explore \(fact.planet.name)"
                content.body = fact.text
                content.sound = .default
                content.threadIdentifier = "planet-facts"
                content.userInfo = ["planetID": fact.planet.id]
                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: delivery)
                let request = UNNotificationRequest(
                    identifier: prefix + String(day), content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
                do {
                    try await center.add(request)
                    count += 1
                } catch {
                    onError(error.localizedDescription)
                    return
                }
            }
        }
    }
}
