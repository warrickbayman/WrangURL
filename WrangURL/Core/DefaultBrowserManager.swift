import AppKit
import Observation
import os

/// Checks and sets WrangURL as the system default handler for http/https.
@MainActor
@Observable
final class DefaultBrowserManager {
    private(set) var isDefault = false
    private(set) var lastError: String?

    private static let schemes = ["http", "https"]
    private static let logger = Logger(subsystem: "com.thepublicgood.wrangurl", category: "default-browser")

    init() {
        refresh()
    }

    func refresh() {
        isDefault = Self.schemes.allSatisfy { scheme in
            guard let probe = URL(string: "\(scheme)://example.com"),
                  let handler = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return false }
            return Bundle(url: handler)?.bundleIdentifier == Bundle.main.bundleIdentifier
        }
    }

    /// macOS shows its own confirmation dialog; the user may decline.
    func makeDefault() async {
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
