import AppKit

/// Menubar-only apps have no Dock icon. While any of our windows is open, show one
/// so the window can be found with ⌘-Tab.
@MainActor
enum DockPresence {
    private static var openWindowCount = 0

    static func windowDidOpen() {
        openWindowCount += 1
        NSApp.setActivationPolicy(.regular)
    }

    static func windowDidClose() {
        openWindowCount = max(0, openWindowCount - 1)
        if openWindowCount == 0 {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

/// An app window that brings WrangURL forward when shown and keeps `DockPresence` in sync.
@MainActor
final class ManagedWindow {
    let window: NSWindow
    var onClose: () -> Void = {}
    private(set) var isOpen = false
    private var hasBeenShown = false

    init(window: NSWindow) {
        self.window = window
        window.isReleasedWhenClosed = false
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.didClose()
            }
        }
    }

    func show() {
        if !isOpen {
            isOpen = true
            DockPresence.windowDidOpen()
        }
        if !hasBeenShown {
            hasBeenShown = true
            window.center()
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window.close()
    }

    private func didClose() {
        guard isOpen else { return }
        isOpen = false
        DockPresence.windowDidClose()
        onClose()
    }
}
