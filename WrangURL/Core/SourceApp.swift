import AppKit

/// The app a link was clicked in.
struct SourceApp: Codable, Hashable, Sendable {
    /// Bundle identifier.
    let id: String
    let name: String
}

extension SourceApp {
    /// The app that sent the Apple Event being handled, e.g. the one in `application(_:open:)`.
    /// Only valid while that event is being handled.
    ///
    /// Helper processes (Electron, WebKit, XPC services) are mapped to the app that contains them.
    /// Nil when the sender isn't an app, such as `open` in Terminal, or has already quit. The
    /// frontmost app isn't used as a fallback: it's often the browser the previous link went to.
    @MainActor
    static func forCurrentAppleEvent() -> SourceApp? {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let pid = event?.attributeDescriptor(forKeyword: keySenderPIDAttr)?.int32Value
        let sender = pid.flatMap { NSRunningApplication(processIdentifier: $0) }
        return sender.flatMap(from)
    }

    /// The outermost app containing `app`, or nil if `app` isn't inside an app bundle or is WrangURL.
    @MainActor
    private static func from(_ app: NSRunningApplication) -> SourceApp? {
        guard let bundleURL = app.bundleURL,
              let appURL = containingAppURL(of: bundleURL) else { return nil }

        let source: SourceApp?
        if appURL.standardizedFileURL == bundleURL.standardizedFileURL {
            source = app.bundleIdentifier.map { SourceApp(id: $0, name: app.localizedName ?? displayName(of: appURL)) }
        } else if let parent = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleURL?.standardizedFileURL == appURL.standardizedFileURL
        }), let id = parent.bundleIdentifier {
            source = SourceApp(id: id, name: parent.localizedName ?? displayName(of: appURL))
        } else {
            source = Bundle(url: appURL)?.bundleIdentifier.map { SourceApp(id: $0, name: displayName(of: appURL)) }
        }
        return source?.id == Bundle.main.bundleIdentifier ? nil : source
    }

    /// The outermost `.app` bundle in `url`'s path, e.g. `/Applications/Slack.app` for
    /// `/Applications/Slack.app/Contents/Frameworks/Slack Helper.app`.
    nonisolated static func containingAppURL(of url: URL) -> URL? {
        var appURL: URL?
        var current = url.standardizedFileURL
        while current.pathComponents.count > 1 {
            if current.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
                appURL = current
            }
            current = current.deletingLastPathComponent()
        }
        return appURL
    }

    private static func displayName(of appURL: URL) -> String {
        FileManager.default.displayName(atPath: appURL.path).replacing(/\.app$/, with: "")
    }
}
