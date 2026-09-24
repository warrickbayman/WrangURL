import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let router = URLRouter()
    let defaultBrowser = DefaultBrowserManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
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
