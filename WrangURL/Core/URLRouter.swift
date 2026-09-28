import AppKit
import Observation
import os

/// Receives URLs opened on the system and sends each one to the browser its rules select.
@MainActor
@Observable
final class URLRouter {
    struct Entry: Identifiable {
        let id = UUID()
        let url: URL
        let date: Date
        let targetName: String
        let ruleName: String?
    }

    /// A URL that arrived before launch finished, with what was known when it arrived.
    private struct PendingURL {
        let url: URL
        let source: SourceApp?
        let modifiers: ModifierKeys
    }

    private(set) var recent: [Entry] = []

    @ObservationIgnored private let config: ConfigStore
    @ObservationIgnored private let browsers: BrowserRegistry
    @ObservationIgnored private let history: HistoryStore
    @ObservationIgnored private let picker = BrowserPickerController()
    @ObservationIgnored private var pending: [PendingURL] = []
    @ObservationIgnored private var isReady = false
    @ObservationIgnored private var matcherCache: (rules: [Rule], matcher: RuleMatcher)?

    private static let recentLimit = 10
    private static let logger = Logger(subsystem: "com.thepublicgood.wrangurl", category: "router")

    init(config: ConfigStore, browsers: BrowserRegistry, history: HistoryStore) {
        self.config = config
        self.browsers = browsers
        self.history = history
    }

    func markReady() {
        isReady = true
        let queued = pending
        pending.removeAll()
        for item in queued {
            route(item.url, from: item.source, heldModifiers: item.modifiers)
        }
    }

    /// Routes URLs clicked in `source`, the app they came from, if known.
    func handle(_ urls: [URL], from source: SourceApp? = nil) {
        // Read the keys now: by the time a queued URL is routed, the user may have let go.
        let modifiers = ModifierKeys(NSEvent.modifierFlags)
        guard isReady else {
            pending.append(contentsOf: urls.map { PendingURL(url: $0, source: source, modifiers: modifiers) })
            Self.logger.info("Queued \(urls.count) URL(s) until launch finishes")
            return
        }
        for url in urls {
            route(url, from: source, heldModifiers: modifiers)
        }
    }

    var planner: RoutePlanner {
        let ownID = Bundle.main.bundleIdentifier
        return RoutePlanner(
            settings: config.config.settings,
            installedBrowserIDs: browsers.browsers.map(\.id),
            isAvailable: { id in
                id != ownID && NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil
            }
        )
    }

    private var matcher: RuleMatcher {
        let rules = config.config.rules
        if let cache = matcherCache, cache.rules == rules {
            return cache.matcher
        }
        let matcher = RuleMatcher(rules: rules)
        matcherCache = (rules, matcher)
        return matcher
    }

    /// What would happen to a URL clicked in `source`, without opening it. Used by the URL tester.
    func preview(
        _ url: URL, from source: SourceApp? = nil, heldModifiers: ModifierKeys = []
    ) -> (rule: Rule?, decision: RouteDecision) {
        let rule = matcher.match(url, from: source?.id)
        return (rule, planner.decide(for: url, matchedRule: rule, heldModifiers: heldModifiers))
    }

    /// The URL as it should appear in the log, following the "Include URLs in logs" setting.
    private func loggable(_ url: URL) -> String {
        config.config.settings.logsURLs ? url.absoluteString : "<URL hidden>"
    }

    private func route(_ url: URL, from source: SourceApp?, heldModifiers: ModifierKeys) {
        let (rule, decision) = preview(url, from: source, heldModifiers: heldModifiers)
        Self.logger.info("Received \(self.loggable(url), privacy: .public) from \(source?.id ?? "unknown app", privacy: .public); rule: \(rule?.displayName ?? "none", privacy: .public); modifiers: \(heldModifiers.symbols, privacy: .public); decision: \(String(describing: decision), privacy: .public)")

        switch decision {
        case .open(let browserID):
            open(url, inBrowserWithID: browserID, rule: rule, source: source)
        case .pick(let browserIDs):
            presentPicker(for: url, browserIDs: browserIDs, rule: rule, source: source)
        case .noBrowserAvailable:
            Self.logger.error("No browser available for \(self.loggable(url), privacy: .public)")
        }
    }

    private func presentPicker(for url: URL, browserIDs: [String], rule: Rule?, source: SourceApp?) {
        let choices = browserIDs.compactMap(browsers.resolve)
        guard choices.count > 1 else {
            if let only = choices.first {
                open(url, inBrowserWithID: only.id, rule: rule, source: source)
            }
            return
        }
        picker.present(url: url, browsers: choices) { [weak self] browser in
            guard let self else { return }
            guard let browser else {
                Self.logger.info("Picker cancelled for \(self.loggable(url), privacy: .public)")
                return
            }
            self.open(url, inBrowserWithID: browser.id, rule: rule, source: source)
        }
    }

    private func open(_ url: URL, inBrowserWithID browserID: String, rule: Rule?, source: SourceApp?) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browserID) else {
            Self.logger.error("Browser \(browserID, privacy: .public) is not installed")
            return
        }
        // Never hand a URL back to ourselves, or we'd loop forever.
        guard Bundle(url: appURL)?.bundleIdentifier != Bundle.main.bundleIdentifier else {
            Self.logger.fault("Refusing to open URL with WrangURL itself")
            return
        }

        let logger = Self.logger
        let loggedURL = loggable(url)
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                logger.error("Failed to open \(loggedURL, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        let name = browsers.resolve(browserID)?.name ?? appURL.lastPathComponent
        recent.insert(Entry(url: url, date: .now, targetName: name, ruleName: rule?.displayName), at: 0)
        if recent.count > Self.recentLimit {
            recent.removeLast(recent.count - Self.recentLimit)
        }
        if config.config.settings.keepsHistory {
            history.record(HistoryEntry(
                url: url, date: .now, browserID: browserID, browserName: name,
                ruleName: rule?.displayName, sourceApp: source
            ))
        }
    }
}
