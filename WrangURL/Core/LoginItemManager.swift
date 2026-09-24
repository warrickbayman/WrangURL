import Observation
import ServiceManagement
import os

/// Registers WrangURL to open at login. The status is always read from the system,
/// since the user can change it in System Settings → General → Login Items.
@MainActor
@Observable
final class LoginItemManager {
    private(set) var status: SMAppService.Status = .notRegistered
    private(set) var lastError: String?

    private static let logger = Logger(subsystem: "com.thepublicgood.wrangurl", category: "login-item")

    init() {
        refresh()
    }

    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    /// Registered, but the user must allow it in System Settings before it takes effect.
    var requiresApproval: Bool {
        status == .requiresApproval
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            Self.logger.error("Failed to \(enabled ? "register" : "unregister") login item: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
