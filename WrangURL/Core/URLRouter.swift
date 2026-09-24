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

    private(set) var recent: [Entry] = []

    @ObservationIgnored private let config: ConfigStore
    @ObservationIgnored private let browsers: BrowserRegistry
    @ObservationIgnored private let picker = BrowserPickerController()
    @ObservationIgnored private var pending: [URL] = []
    @ObservationIgnored private var isReady = false
    @ObservationIgnored private var matcherCache: (rules: [Rule], matcher: RuleMatcher)?

    private static let recentLimit = 10
    private static let logger = Logger(subsystem: "com.thepublicgood.wrangurl", category: "router")

    init(config: ConfigStore, browsers: BrowserRegistry) {
        self.config = config
        self.browsers = browsers
    }

    func markReady() {
        isReady = true
        let queued = pending
        pending.removeAll()
        handle(queued)
    }

    func handle(_ urls: [URL]) {
        guard isReady else {
            pending.append(contentsOf: urls)
            Self.logger.info("Queued \(urls.count) URL(s) until launch finishes")
            return
        }
        urls.forEach(route)
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

    private func route(_ url: URL) {
        let rule = matcher.match(url)
        let decision = planner.decide(for: url, matchedRule: rule)
        Self.logger.info("Received \(url.absoluteString, privacy: .public); rule: \(rule?.name ?? "none", privacy: .public); decision: \(String(describing: decision), privacy: .public)")

        switch decision {
        case .open(let browserID):
            open(url, inBrowserWithID: browserID, rule: rule)
        case .pick(let browserIDs):
            presentPicker(for: url, browserIDs: browserIDs, rule: rule)
        case .noBrowserAvailable:
            Self.logger.error("No browser available for \(url.absoluteString, privacy: .public)")
        }
    }

    private func presentPicker(for url: URL, browserIDs: [String], rule: Rule?) {
        let choices = browserIDs.compactMap(browsers.resolve)
        guard choices.count > 1 else {
            if let only = choices.first {
                open(url, inBrowserWithID: only.id, rule: rule)
            }
            return
        }
        picker.present(url: url, browsers: choices) { [weak self] browser in
            guard let self, let browser else { return }
            self.open(url, inBrowserWithID: browser.id, rule: rule)
        }
    }

    private func open(_ url: URL, inBrowserWithID browserID: String, rule: Rule?) {
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
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                logger.error("Failed to open \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        let name = browsers.resolve(browserID)?.name ?? appURL.lastPathComponent
        recent.insert(Entry(url: url, date: .now, targetName: name, ruleName: rule?.name), at: 0)
        if recent.count > Self.recentLimit {
            recent.removeLast(recent.count - Self.recentLimit)
        }
    }
}
