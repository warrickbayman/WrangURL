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
    }

    /// Bundle identifier of the app currently handling https URLs.
    var currentDefaultBrowserID: String? {
        guard let probe = URL(string: "https://example.com"),
              let handler = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return nil }
        return Bundle(url: handler)?.bundleIdentifier
    }

    func refresh() {
        isDefault = Self.schemes.allSatisfy { scheme in
            guard let probe = URL(string: "\(scheme)://example.com"),
                  let handler = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return false }
            return Self.isWrangURL(handler)
        }
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
    func makeDefault() async {
        captureFallbackIfNeeded()
        do {
            for scheme in Self.schemes {
                try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme)
            }
            lastError = nil
        } catch {
            Self.logger.error("Failed to set default browser: \(error.localizedDescription, privacy: .public)")
            lastError = error.localizedDescription
        }
        refresh()
    }
}
