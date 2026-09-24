import AppKit
import SwiftUI

enum SettingsTab: Int, CaseIterable {
    case general
    case rules

    var title: String {
        switch self {
        case .general: "General"
        case .rules: "Rules"
        }
    }

    var symbolName: String {
        switch self {
        case .general: "gearshape"
        case .rules: "list.bullet.rectangle"
        }
    }
}

/// Owns the Settings window. AppKit-managed rather than a SwiftUI `Settings` scene,
/// because a menubar-only app can't reliably open that scene from outside a view.
@MainActor
@Observable
final class SettingsWindowController {
    /// Builds each tab's content; set by the app so views get the shared environment.
    @ObservationIgnored var makeContent: (SettingsTab) -> AnyView = { _ in AnyView(EmptyView()) }
    /// Called each time the window is shown, e.g. to refresh the browser list.
    @ObservationIgnored var onShow: () -> Void = {}

    @ObservationIgnored private var window: NSWindow?
    @ObservationIgnored private let tabController = NSTabViewController()

    func show(tab: SettingsTab = .general) {
        onShow()
        let window = window ?? makeWindow()
        tabController.selectedTabViewItemIndex = tab.rawValue

        // Menubar-only apps have no Dock icon; show one while Settings is open so
        // the window can be found with ⌘-Tab.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        tabController.tabStyle = .toolbar
        for tab in SettingsTab.allCases {
            let content = NSHostingController(rootView: makeContent(tab))
            content.title = tab.title
            let item = NSTabViewItem(viewController: content)
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.symbolName, accessibilityDescription: tab.title)
            tabController.addTabViewItem(item)
        }

        let window = NSWindow(contentViewController: tabController)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 680, height: 520))
        window.center()

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated {
                _ = NSApp.setActivationPolicy(.accessory)
            }
        }

        self.window = window
        return window
    }
}
