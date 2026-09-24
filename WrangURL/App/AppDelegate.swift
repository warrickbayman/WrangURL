import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let config: ConfigStore
    let browsers: BrowserRegistry
    let router: URLRouter
    let defaultBrowser: DefaultBrowserManager
    let settingsWindow = SettingsWindowController()

    override init() {
        config = ConfigStore()
        browsers = BrowserRegistry()
        router = URLRouter(config: config, browsers: browsers)
        defaultBrowser = DefaultBrowserManager(config: config)
        super.init()

        settingsWindow.makeContent = { [unowned self] tab in
            switch tab {
            case .general: AnyView(GeneralSettingsView().appEnvironment(self))
            case .rules: AnyView(RulesSettingsView().appEnvironment(self))
            }
        }
        settingsWindow.onShow = { [unowned self] in
            browsers.refresh()
            defaultBrowser.refresh()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaultBrowser.captureFallbackIfNeeded()
        // On a cold launch triggered by a link, macOS may deliver the URL before
        // launch finishes. The router queues it until we mark it ready here.
        router.markReady()

        #if DEBUG
        // Launch with `-DebugSettingsTab <general|rules>` to open Settings directly (for UI work).
        if let name = UserDefaults.standard.string(forKey: "DebugSettingsTab"),
           let tab = SettingsTab.allCases.first(where: { $0.title.lowercased() == name }) {
            settingsWindow.show(tab: tab)
        }
        #endif
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        defaultBrowser.refresh()
    }

    /// Launching the app again (e.g. from Finder or Spotlight) opens Settings,
    /// since there is no Dock icon to click.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        router.handle(urls)
    }
}
