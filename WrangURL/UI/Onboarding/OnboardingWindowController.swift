import AppKit
import SwiftUI

/// Shows the first-run setup. Closing the window any way counts as finishing, so it
/// doesn't reappear on every launch; it can be run again from Settings.
@MainActor
@Observable
final class OnboardingWindowController {
    /// Builds the content for a fresh run; `finish(openRules)` closes the window.
    @ObservationIgnored var makeContent: (_ step: OnboardingStep, _ finish: @escaping (_ openRules: Bool) -> Void) -> AnyView = { _, _ in
        AnyView(EmptyView())
    }
    /// Called once the window has closed.
    @ObservationIgnored var onFinish: (_ openRules: Bool) -> Void = { _ in }

    @ObservationIgnored private var managedWindow: ManagedWindow?
    @ObservationIgnored private var openRulesOnClose = false

    func show(step: OnboardingStep = .fallback) {
        let managedWindow = managedWindow ?? makeWindow()
        if !managedWindow.isOpen {
            // Start from a fresh view each run.
            managedWindow.window.contentViewController = NSHostingController(rootView: makeContent(step) { [weak self] openRules in
                self?.finish(openRules: openRules)
            })
        }
        managedWindow.show()
    }

    private func finish(openRules: Bool) {
        openRulesOnClose = openRules
        managedWindow?.close()
    }

    private func makeWindow() -> ManagedWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to WrangURL"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        let managedWindow = ManagedWindow(window: window)
        managedWindow.onClose = { [weak self] in
            guard let self else { return }
            let openRules = openRulesOnClose
            openRulesOnClose = false
            onFinish(openRules)
        }
        self.managedWindow = managedWindow
        return managedWindow
    }
}
