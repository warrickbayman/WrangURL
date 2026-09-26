import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let config: ConfigStore
    let history: HistoryStore
    let browsers: BrowserRegistry
    let router: URLRouter
    let defaultBrowser: DefaultBrowserManager
    let loginItem = LoginItemManager()
    let updates = UpdateManager(startingUpdater: !AppDelegate.isRunningTests)
    let settingsWindow = SettingsWindowController()
    let historyWindow = HistoryWindowController()
    let onboardingWindow = OnboardingWindowController()

    /// The app hosts the unit tests; skip startup side effects so tests don't
    /// open windows or change the user's config.
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    override init() {
        config = ConfigStore()
        history = HistoryStore()
        browsers = BrowserRegistry()
        router = URLRouter(config: config, browsers: browsers, history: history)
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
            loginItem.refresh()
        }

        historyWindow.makeContent = { [unowned self] in AnyView(HistoryView().appEnvironment(self))
        }

        onboardingWindow.makeContent = { [unowned self] step, finish in
            AnyView(OnboardingView(step: step, onFinish: finish).appEnvironment(self))
        }
        onboardingWindow.onFinish = { [unowned self] openRules in
            config.update { $0.settings.hasCompletedOnboarding = true }
            if openRules {
                settingsWindow.show(tab: .rules)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // On a cold launch triggered by a link, macOS may deliver the URL before
        // launch finishes. The router queues it until we mark it ready here.
        router.markReady()

        guard !Self.isRunningTests else { return }

        defaultBrowser.captureFallbackIfNeeded()
        if !config.config.settings.hasCompletedOnboarding {
            onboardingWindow.show(step: Self.debugOnboardingStep ?? .fallback)
        }

        #if DEBUG
        // Launch with `-DebugSettingsTab <general|rules>` to open Settings directly (for UI work).
        if let name = UserDefaults.standard.string(forKey: "DebugSettingsTab"),
           let tab = SettingsTab.allCases.first(where: { $0.title.lowercased() == name }) {
            settingsWindow.show(tab: tab)
        }
        // Launch with `-DebugShowHistory YES` to open the History window.
        if UserDefaults.standard.bool(forKey: "DebugShowHistory") {
            historyWindow.show()
        }
        if let step = Self.debugOnboardingStep {
            onboardingWindow.show(step: step)
        }
        // Launch with `-DebugShowPicker <bundle IDs, comma-separated>` to show the picker
        // with those browsers, e.g. for screenshots. Choosing a browser does nothing.
        if let ids = UserDefaults.standard.string(forKey: "DebugShowPicker") {
            let choices = ids.split(separator: ",").compactMap { browsers.resolve(String($0)) }
            let url = URL(string: UserDefaults.standard.string(forKey: "DebugPickerURL") ?? "http://localhost:3000/dashboard")!
            debugPicker.present(url: url, browsers: choices) { _ in }
        }
        #endif
    }

    #if DEBUG
    private let debugPicker = BrowserPickerController()
    #endif

    /// Launch with `-DebugOnboardingStep <0-3>` to open setup on a given step (debug builds only).
    private static var debugOnboardingStep: OnboardingStep? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "DebugOnboardingStep").flatMap(Int.init).flatMap(OnboardingStep.init)
        #else
        nil
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
