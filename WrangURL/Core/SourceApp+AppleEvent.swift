import AppKit

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

    /// Regular apps that are running now, by name, excluding WrangURL.
    @MainActor
    static var running: [SourceApp] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(from)
            .filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The app at `appURL`, e.g. one the user chose in an open panel.
    static func app(at appURL: URL) -> SourceApp? {
        guard let id = Bundle(url: appURL)?.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return nil }
        return SourceApp(id: id, name: displayName(of: appURL))
    }

    private static func displayName(of appURL: URL) -> String {
        FileManager.default.displayName(atPath: appURL.path).replacing(/\.app$/, with: "")
    }
}
