import AppKit
import Observation
import os

/// Receives URLs opened on the system and forwards them to a browser.
///
/// Spike: every URL is forwarded to Safari. Rule matching replaces this in milestone 3.
@MainActor
@Observable
final class URLRouter {
    struct Entry: Identifiable {
        let id = UUID()
        let url: URL
        let date: Date
        let targetName: String
    }

    private(set) var recent: [Entry] = []

    @ObservationIgnored private var pending: [URL] = []
    @ObservationIgnored private var isReady = false

    private static let spikeTargetBundleID = "com.apple.Safari"
    private static let recentLimit = 10
    private static let logger = Logger(subsystem: "com.thepublicgood.wrangurl", category: "router")

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

    private func route(_ url: URL) {
        Self.logger.info("Received \(url.absoluteString, privacy: .public)")

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.spikeTargetBundleID) else {
            Self.logger.error("Target browser \(Self.spikeTargetBundleID, privacy: .public) is not installed")
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
            } else {
                logger.info("Opened \(url.absoluteString, privacy: .public) in \(appURL.lastPathComponent, privacy: .public)")
            }
        }

        let name = FileManager.default.displayName(atPath: appURL.path)
        recent.insert(Entry(url: url, date: .now, targetName: name), at: 0)
        if recent.count > Self.recentLimit {
            recent.removeLast(recent.count - Self.recentLimit)
        }
    }
}
