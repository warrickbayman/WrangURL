import AppKit
import Observation
import Sparkle
import UserNotifications

/// Checks for new releases with Sparkle. The feed URL and signing key are in Info.plist
/// (see `project.yml`); Sparkle keeps its own preferences in user defaults.
///
/// WrangURL has no Dock icon, so Sparkle would show an update found by a scheduled check
/// behind other apps, where it's easily missed. Instead this implements Sparkle's
/// gentle reminders: unless Sparkle is about to show the update in focus (just after launch),
/// it posts a notification and offers the update in the menu, and the alert is only
/// brought forward when the user picks one of those.
/// See https://sparkle-project.org/documentation/gentle-reminders
@MainActor
@Observable
final class UpdateManager: NSObject {
    private(set) var canCheckForUpdates = false
    /// The version of an update found by a scheduled check that the user hasn't looked at yet.
    private(set) var pendingUpdateVersion: String?

    // Assigned right after `super.init()`, because the controller needs `self` as its delegate.
    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    @ObservationIgnored private var observation: NSKeyValueObservation?

    nonisolated private static let notificationID = "update-available"

    /// Pass `startingUpdater: false` when hosting tests, so nothing is checked in the background.
    init(startingUpdater: Bool) {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: startingUpdater,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
        if startingUpdater {
            UNUserNotificationCenter.current().delegate = self
        }
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            access(keyPath: \.automaticallyChecksForUpdates)
            return controller.updater.automaticallyChecksForUpdates
        }
        set {
            withMutation(keyPath: \.automaticallyChecksForUpdates) {
                controller.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    var currentVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    /// Checks for updates, or brings a pending update's alert to the front.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    private func remind(version: String) {
        pendingUpdateVersion = version
        let center = UNUserNotificationCenter.current()
        Task {
            guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = "WrangURL \(version) is available"
            content.body = "Click to see what's new and install the update."
            let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: nil)
            try? await center.add(request)
        }
    }

    private func clearReminder() {
        pendingUpdateVersion = nil
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [Self.notificationID])
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }
}

// Sparkle calls these on the main thread.
extension UpdateManager: SPUStandardUserDriverDelegate {
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        // Let Sparkle show the alert when it can do so in front (just after launch);
        // otherwise we remind the user and show it when they ask.
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate, !state.userInitiated else { return }
        let version = update.displayVersionString
        MainActor.assumeIsolated {
            remind(version: version)
        }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        MainActor.assumeIsolated {
            clearReminder()
        }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated {
            clearReminder()
        }
    }
}

extension UpdateManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier == Self.notificationID else { return }
        await checkForUpdates()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}
