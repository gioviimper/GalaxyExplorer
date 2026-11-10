import Foundation
import UserNotifications

// Notification taps restore the matching planet or astronomical event.
extension AppNotificationService {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let id = response.notification.request.content.userInfo["planetID"] as? String
        let data = response.notification.request.content.userInfo["skyEvent"] as? Data
        await MainActor.run {
            if let data, let event = try? JSONDecoder().decode(SkyEvent.self, from: data) {
                LocalSkyEventService.shared.selectedEvent = event
            } else {
                self.destination = id
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Keep the immersive foreground experience quiet; alerts remain in Notification Center.
        [.list]
    }
}
