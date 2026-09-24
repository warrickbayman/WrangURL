import AppKit
import Observation
import os

/// Checks and sets WrangURL as the system default handler for http/https.
@MainActor
@Observable
final class DefaultBrowserManager {
    private(set) var isDefault = false
    private(set) var lastError: String?

    @ObservationIgnored private let config: ConfigStore

    private static let schemes = ["http", "https"]
    private static let logger = Logger(subsystem: "com.thepublicgood.wrangurl", category: "default-browser")

    init(config: ConfigStore) {
        self.config = config
        refresh()

        // There's no notification for default-browser changes. Re-check whenever the user
        // switches apps, e.g. on leaving System Settings, so the menubar icon stays accurate.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
    }

    /// Bundle identifier of the app currently handling https URLs.
    var currentDefaultBrowserID: String? {
        guard let probe = URL(string: "https://example.com"),
              let handler = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return nil }
        return Bundle(url: handler)?.bundleIdentifier
    }

    func refresh() {
        isDefault = Self.schemes.allSatisfy(Self.isHandler)
    }

    private static func isHandler(for scheme: String) -> Bool {
        guard let probe = URL(string: "\(scheme)://example.com"),
              let handler = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return false }
        return isWrangURL(handler)
    }

    /// Compares the path as well as the bundle ID: the sandbox can't read bundles in
    /// arbitrary locations (e.g. an Xcode build in ~/Library/Developer).
    private static func isWrangURL(_ appURL: URL) -> Bool {
        appURL.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
            || Bundle(url: appURL)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    /// Remembers the user's current browser as the fallback, unless one is already set.
    /// Must run before WrangURL takes over, or the previous browser is lost.
    func captureFallbackIfNeeded() {
        guard config.config.settings.fallbackBrowserID == nil,
              let current = currentDefaultBrowserID,
              current != Bundle.main.bundleIdentifier else { return }
        config.update { $0.settings.fallbackBrowserID = current }
        Self.logger.info("Captured \(current, privacy: .public) as fallback browser")
    }

    /// macOS shows its own confirmation dialog; the user may decline.
    ///
    /// Confirming the dialog for http also makes WrangURL the handler for https, and a
    /// second request then fails ("The file couldn't be opened"). So schemes already
    /// handled are skipped, and success is judged by the final state, not each call.
    func makeDefault() async {
        captureFallbackIfNeeded()
        var failure: (any Error)?
        for scheme in Self.schemes where !Self.isHandler(for: scheme) {
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme)
            } catch {
                let nsError = error as NSError
                Self.logger.error("Failed to set default for \(scheme, privacy: .public): \(nsError.domain, privacy: .public) \(nsError.code) \(nsError.localizedDescription, privacy: .public)")
                failure = error
            }
        }
        refresh()
        lastError = isDefault ? nil : failure?.localizedDescription ?? "WrangURL wasn't set as the default browser."
    }
}
