import Foundation
import UserNotifications

/// Posts a local notification when a scan finds something worth mentioning.
///
/// Entirely optional: the user opts in from Settings, and a denied or
/// undetermined system permission just means nothing appears rather than an
/// error anywhere in the app.
@MainActor
final class ScanNotifier {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// Ask the system for permission, if it has not been asked before.
    /// Safe to call every time the user turns the setting on — the system
    /// only prompts once and remembers the answer.
    func requestAuthorizationIfNeeded() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Report what a finished scan found. A no-op when nothing new was
    /// imported — a notification for "found nothing" would train the user
    /// to ignore Velocity's notifications entirely.
    func notify(newCommitCount: Int, failedRepositoryCount: Int) {
        guard newCommitCount > 0 || failedRepositoryCount > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Velocity"
        content.body = Self.body(newCommitCount: newCommitCount, failedRepositoryCount: failedRepositoryCount)
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }

    nonisolated static func body(newCommitCount: Int, failedRepositoryCount: Int) -> String {
        var parts: [String] = []
        if newCommitCount > 0 {
            parts.append("\(newCommitCount) commit\(newCommitCount == 1 ? "" : "s") imported")
        }
        if failedRepositoryCount > 0 {
            parts.append("\(failedRepositoryCount) repositor\(failedRepositoryCount == 1 ? "y" : "ies") failed to scan")
        }
        return parts.joined(separator: " · ")
    }
}
