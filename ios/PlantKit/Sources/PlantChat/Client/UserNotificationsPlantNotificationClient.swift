import Foundation
import UserNotifications

/// Local notifications. Asks for permission the first time one is posted, which is when the plant first has a problem.
@MainActor
public final class UserNotificationsPlantNotificationClient: NSObject, PlantNotificationClient, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    public func post(title: String, body: String) {
        let center = center
        Task {
            guard await Self.isAllowed(center) else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }

    /// Until M6 the app only runs in the foreground, so banners must show there.
    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private static func isAllowed(_ center: UNUserNotificationCenter) async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}
