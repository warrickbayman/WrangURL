import AppKit
import Observation

struct Browser: Identifiable, Hashable, Sendable {
    /// Bundle identifier.
    let id: String
    let name: String
    let url: URL
}

/// Discovers installed apps that can open https URLs.
@MainActor
@Observable
final class BrowserRegistry {
    private(set) var browsers: [Browser] = []

    @ObservationIgnored private var iconCache: [String: NSImage] = [:]
    @ObservationIgnored private var menuIconCache: [String: NSImage] = [:]

    init() {
        refresh()
    }

    func refresh() {
        guard let probe = URL(string: "https://example.com") else { return }
        let candidates = NSWorkspace.shared.urlsForApplications(toOpen: probe)
            .filter { Self.isUserFacing($0, home: Self.userHome) }

        var seen = Set<String>()
        browsers = candidates
            .compactMap { appURL -> Browser? in
                guard let id = Bundle(url: appURL)?.bundleIdentifier,
                      id != Bundle.main.bundleIdentifier,
                      seen.insert(id).inserted else { return nil }
                return Browser(id: id, name: Self.displayName(of: appURL), url: appURL)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func browser(withID id: String) -> Browser? {
        browsers.first { $0.id == id }
    }

    /// Like `browser(withID:)`, but also finds apps hidden from the list (e.g. in unusual locations).
    func resolve(_ id: String) -> Browser? {
        if let browser = browser(withID: id) {
            return browser
        }
        guard id != Bundle.main.bundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        return Browser(id: id, name: Self.displayName(of: appURL), url: appURL)
    }

    func icon(for browser: Browser) -> NSImage {
        NSWorkspace.shared.icon(forFile: browser.url.path)
    }

    /// Full-size icon for SwiftUI views (size it with `.resizable().frame(...)`).
    func icon(forID id: String) -> NSImage? {
        if let cached = iconCache[id] {
            return cached
        }
        guard let browser = resolve(id) else { return nil }
        let icon = icon(for: browser)
        iconCache[id] = icon
        return icon
    }

    /// 16pt icon for menus and pickers, which ignore SwiftUI frame modifiers.
    func menuIcon(forID id: String) -> NSImage? {
        if let cached = menuIconCache[id] {
            return cached
        }
        guard let icon = icon(forID: id)?.copy() as? NSImage else { return nil }
        icon.size = NSSize(width: 16, height: 16)
        menuIconCache[id] = icon
        return icon
    }

    private static func displayName(of appURL: URL) -> String {
        FileManager.default.displayName(atPath: appURL.path).replacing(/\.app$/, with: "")
    }

    /// Hides apps that register for https but aren't browsers a user installed,
    /// e.g. Playwright's "Chrome for Testing" in ~/Library/Caches or Xcode build products.
    nonisolated static func isUserFacing(_ appURL: URL, home: URL) -> Bool {
        let path = appURL.standardizedFileURL.path
        let allowedRoots = [
            "/Applications/",
            home.appending(path: "Applications").path + "/",
            "/System/Applications/",
            "/System/Cryptexes/App/System/Applications/",
            "/System/Volumes/Preboot/Cryptexes/App/System/Applications/",
        ]
        return allowedRoots.contains { path.hasPrefix($0) }
    }

    /// The real home directory; `NSHomeDirectory()` points into the container when sandboxed.
    nonisolated static var userHome: URL {
        if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
            return URL(filePath: String(cString: dir), directoryHint: .isDirectory)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}
