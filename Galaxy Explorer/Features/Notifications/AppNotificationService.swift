import Combine
import SwiftUI
import UserNotifications

// Notifications stay opt-in. Opening a fact goes straight to its planet.
@MainActor
final class AppNotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationService()
    @Published var destination: String?
    @Published var authorization: UNAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    private let center = UNUserNotificationCenter.current()
    private let factScheduler = PlanetFactNotificationScheduler()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestPermission() async {
        do { _ = try await center.requestAuthorization(options: [.alert, .sound]) } catch {
            errorMessage = error.localizedDescription
        }
        await refresh()
    }

    func refresh() async {
        authorization = await center.notificationSettings().authorizationStatus
        reschedule()
        LocalSkyEventService.shared.refreshIfNeeded()
    }

    func reschedule() {
        factScheduler.reschedule(authorization: authorization) { [weak self] message in
            self?.errorMessage = message
        }
    }
}
