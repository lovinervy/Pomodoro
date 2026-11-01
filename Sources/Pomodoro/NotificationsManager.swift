import Foundation
import AppKit
import UserNotifications
import PomodoroCore

/// Уведомления macOS + звук при смене фазы.
/// Работает только из .app-бандла (системе нужен bundle id);
/// при `swift run` без бандла тихо отключается.
/// Настройки читаются из UserDefaults в момент события.
@MainActor
final class NotificationsManager: NSObject, UNUserNotificationCenterDelegate {

    private let center = UNUserNotificationCenter.current()
    private var isAvailable = false

    override init() {
        super.init()
        guard Bundle.main.bundleIdentifier != nil else { return }
        isAvailable = true
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func phaseCompleted(finished: Phase, started: Phase) {
        AppSettings.playCurrentSound()
        send(
            title: "\(finished.displayTitle) — готово",
            body: "Далее: \(started.displayTitle), \(Int(started.duration / 60)) мин"
        )
    }

    func cycleFinished(_ cycle: Cycle) {
        AppSettings.playCurrentSound()
        send(title: "Цикл «\(cycle.name)» завершён", body: "Все фазы пройдены 🎉")
    }

    private func send(title: String, body: String) {
        guard isAvailable, AppSettings.bool(AppSettings.notificationsEnabled) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        center.add(request)
    }

    /// Показывать баннер, даже когда приложение активно.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}
