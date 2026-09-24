import AppKit
import SwiftUI
import os

/// Shows the browser picker, one URL at a time. URLs arriving while it's open are queued.
@MainActor
final class BrowserPickerController {
    typealias Completion = @MainActor (Browser?) -> Void

    private struct Request {
        let url: URL
        let browsers: [Browser]
        let completion: Completion
    }

    private var queue: [Request] = []
    private var current: Request?
    private var model: PickerModel?
    private var panel: PickerPanel?

    private static let logger = Logger(subsystem: "com.thepublicgood.wrangurl", category: "picker")

    /// Calls `completion` with the chosen browser, or `nil` if the user cancelled.
    func present(url: URL, browsers: [Browser], completion: @escaping Completion) {
        queue.append(Request(url: url, browsers: browsers, completion: completion))
        if current == nil {
            showNext()
        }
    }

    private func showNext() {
        guard !queue.isEmpty else { return }
        let request = queue.removeFirst()
        current = request

        let icons = Dictionary(uniqueKeysWithValues: request.browsers.map {
            ($0.id, NSWorkspace.shared.icon(forFile: $0.url.path))
        })
        let model = PickerModel(url: request.url, browsers: request.browsers, icons: icons)
        model.onChoose = { [weak self] browser in self?.finish(with: browser) }
        model.onCopy = { [weak self] in self?.copyURLAndCancel() }

        let panel = PickerPanel(contentView: NSHostingView(rootView: BrowserPickerView(model: model)))
        panel.onKeyDown = { [weak self] event in self?.handle(event) ?? false }
        panel.onResignKey = { [weak self] in self?.finish(with: nil) }
        panel.positionNearMouse()
        panel.makeKeyAndOrderFront(nil)
        // The shadow is computed from the window's alpha; recompute once the rounded content has drawn.
        panel.displayIfNeeded()
        panel.invalidateShadow()

        self.model = model
        self.panel = panel
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard let model,
              let action = PickerAction(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers, modifiers: event.modifierFlags)
        else { return false }

        switch action {
        case .choose(let index):
            guard model.browsers.indices.contains(index) else { return true }
            finish(with: model.browsers[index])
        case .chooseSelected:
            finish(with: model.browsers[model.selectedIndex])
        case .moveSelection(let offset):
            model.moveSelection(by: offset)
        case .copyURL:
            copyURLAndCancel()
        case .cancel:
            finish(with: nil)
        }
        return true
    }

    private func copyURLAndCancel() {
        guard let url = current?.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        finish(with: nil)
    }

    private func finish(with browser: Browser?) {
        // Closing the panel resigns key, which calls back in here; `current` guards re-entry.
        guard let request = current else { return }
        current = nil

        panel?.onResignKey = nil
        panel?.orderOut(nil)
        panel = nil
        model = nil

        if browser == nil {
            Self.logger.info("Picker cancelled for \(request.url.absoluteString, privacy: .public)")
        }
        request.completion(browser)
        showNext()
    }
}
