import AppKit
import SwiftUI

/// Shows the History window. Its view is created once and stays live while the app runs.
@MainActor
@Observable
final class HistoryWindowController {
    @ObservationIgnored var makeContent: () -> AnyView = { AnyView(EmptyView()) }

    @ObservationIgnored private var managedWindow: ManagedWindow?

    func show() {
        let managedWindow = managedWindow ?? makeWindow()
        managedWindow.show()
    }

    private func makeWindow() -> ManagedWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "History"
        window.toolbarStyle = .unified

        let content = NSHostingController(rootView: makeContent())
        // Let the view's `.toolbar` and `.searchable` populate the window's toolbar.
        content.sceneBridgingOptions = [.toolbars]
        window.contentViewController = content
        // Installing the content sizes the window to fit it, so set the size afterwards.
        window.setContentSize(NSSize(width: 700, height: 500))

        let managedWindow = ManagedWindow(window: window)
        self.managedWindow = managedWindow
        return managedWindow
    }
}
