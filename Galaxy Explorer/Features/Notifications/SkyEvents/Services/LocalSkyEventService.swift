import Combine
import CoreLocation
import Foundation
import UserNotifications

// A single foreground location request replaces continuous tracking.
// IMCCE receives the rounded observer coordinates only after explicit opt-in in Settings.
@MainActor
final class LocalSkyEventService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocalSkyEventService()
    @Published private(set) var isEnabled = UserDefaults.standard.bool(forKey: "skyEventsEnabled")
    @Published private(set) var events: [SkyEvent] = []
    @Published private(set) var warnings: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var locationMessage: String?
    @Published private(set) var lastUpdated: Date?
    @Published var selectedEvent: SkyEvent?
    private let manager = CLLocationManager()
    private let client = SkyCalendarClient()
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private var task: Task<Void, Never>?
    private var observer: SkyObserver?
    private let prefix = "sky-event-"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        if let data = defaults.data(forKey: "skyObserver") {
            observer = try? JSONDecoder().decode(SkyObserver.self, from: data)
        }
        if let data = defaults.data(forKey: "skyEventCache") {
            events = (try? JSONDecoder().decode([SkyEvent].self, from: data)) ?? []
        }
        lastUpdated = defaults.object(forKey: "skyLastUpdated") as? Date
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: "skyEventsEnabled")
        if enabled {
            Task {
                await AppNotificationService.shared.requestPermission()
                guard isEnabled else { return }
                useCurrentLocation()
            }
        } else {
            manager.stopUpdatingLocation()
            cancelAlerts()
        }
    }

    func useCurrentLocation() {
        guard isEnabled else { return }
        guard CLLocationManager.locationServicesEnabled() else {
            locationMessage =
                "Location Services are disabled. Enable them in iOS Settings to check local events."
            cancelAlerts()
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationMessage = "Finding your area…"
            manager.requestLocation()
        default:
            locationMessage = "Location access is unavailable. No local event alerts will be sent."
            cancelAlerts()
        }
    }

    func refreshIfNeeded(force: Bool = false) {
        guard isEnabled, !isLoading else { return }
        guard
            manager.authorizationStatus == .authorizedAlways
                || manager.authorizationStatus == .authorizedWhenInUse
        else {
            cancelAlerts()
            locationMessage = "Allow location access in iOS Settings to check events in your area."
            return
        }
        guard let observer else {
            locationMessage = "Choose Use my current location to check your area."
            return
        }
        if !force, let lastUpdated, Date.now.timeIntervalSince(lastUpdated) < 86400 { return }
        update(observer)
    }

    func forgetLocation() {
        setEnabled(false)
        observer = nil
        events = []
        lastUpdated = nil
        locationMessage = nil
        for key in ["skyObserver", "skyEventCache", "skyLastUpdated"] { defaults.removeObject(forKey: key) }
    }

    private func update(_ area: SkyObserver) {
        let previous = task
        previous?.cancel()
        isLoading = true
        warnings = []
        task = Task {
            await previous?.value
            guard !Task.isCancelled, isEnabled else { return }
            do {
                let batch = try await client.fetch(observer: area)
                try Task.checkCancellation()
                guard isEnabled else { return }
                events = batch.events
                warnings = batch.warnings
                lastUpdated = .now
                defaults.set(try JSONEncoder().encode(events), forKey: "skyEventCache")
                defaults.set(lastUpdated, forKey: "skyLastUpdated")
                let pending = await center.pendingNotificationRequests()
                center.removePendingNotificationRequests(
                    withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
                let authorization = await center.notificationSettings().authorizationStatus
                if authorization == .authorized || authorization == .provisional {
                    for event in events {
                        try Task.checkCancellation()
                        let content = UNMutableNotificationContent()
                        content.title = event.title
                        content.body =
                            "A viewing opportunity near your saved location begins in about an hour. Open Galaxy Explorer for the time and source. Weather and obstructions may affect visibility."
                        content.sound = .default
                        content.threadIdentifier = "sky-events"
                        content.userInfo = ["skyEvent": try JSONEncoder().encode(event)]
                        let delivery = event.startsAt.addingTimeInterval(-3600)
                        guard delivery > .now else { continue }
                        let trigger = UNTimeIntervalNotificationTrigger(
                            timeInterval: delivery.timeIntervalSinceNow, repeats: false)
                        try await center.add(
                            UNNotificationRequest(
                                identifier: prefix + event.id, content: content, trigger: trigger))
                    }
                }
                isLoading = false
            } catch is CancellationError {
                // A newer location or the off switch owns the next update.
            } catch {
                warnings = [error.localizedDescription]
                isLoading = false
            }
        }
    }

    private func cancelAlerts() {
        let previous = task
        previous?.cancel()
        isLoading = false
        task = Task {
            await previous?.value
            // Cleanup must finish even when a replacement update cancels this task.
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            let delivered = await center.deliveredNotifications()
            center.removeDeliveredNotifications(
                withIdentifiers: delivered.map { $0.request.identifier }.filter { $0.hasPrefix(prefix) })
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.isEnabled else { return }
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                if self.observer == nil { self.useCurrentLocation() }
            } else if status != .notDetermined {
                self.locationMessage = "Location access is unavailable. No local event alerts will be sent."
                self.cancelAlerts()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
        guard let location = locations.last, location.horizontalAccuracy >= 0,
            location.horizontalAccuracy <= 5000,
            abs(location.timestamp.timeIntervalSinceNow) < 300
        else {
            Task { @MainActor in
                self.locationMessage = "Unable to determine your area accurately enough. Please try again."
            }
            return
        }
        let latitude = (location.coordinate.latitude * 100).rounded() / 100
        let longitude = (location.coordinate.longitude * 100).rounded() / 100
        Task { @MainActor in
            guard self.isEnabled else { return }
            let area = SkyObserver(latitude: latitude, longitude: longitude)
            guard area.isValid else { return }
            if self.observer != area {
                self.events = []
                self.lastUpdated = nil
                self.defaults.removeObject(forKey: "skyEventCache")
                self.defaults.removeObject(forKey: "skyLastUpdated")
            }
            self.observer = area
            self.defaults.set(try? JSONEncoder().encode(area), forKey: "skyObserver")
            self.locationMessage = "Using your saved area. Update it after travelling."
            // Remove alerts for the old area before fetching replacements.
            self.cancelAlerts()
            self.update(area)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.locationMessage = "Your location could not be updated. Please try again." }
    }
}
