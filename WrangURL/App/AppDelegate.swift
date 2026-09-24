import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let config: ConfigStore
    let browsers: BrowserRegistry
    let router: URLRouter
    let defaultBrowser: DefaultBrowserManager

    override init() {
        config = ConfigStore()
        browsers = BrowserRegistry()
        router = URLRouter(config: config, browsers: browsers)
        defaultBrowser = DefaultBrowserManager(config: config)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaultBrowser.captureFallbackIfNeeded()
        // On a cold launch triggered by a link, macOS may deliver the URL before
        // launch finishes. The router queues it until we mark it ready here.
        router.markReady()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        defaultBrowser.refresh()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        router.handle(urls)
    }
}
