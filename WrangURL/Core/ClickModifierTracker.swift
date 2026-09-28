import AppKit

/// Remembers the modifier keys held for the last left click in any app, so a link that
/// arrives after the keys were released still counts as modifier-clicked.
///
/// A global monitor sees mouse events without Accessibility or Input Monitoring permission;
/// only keyboard events need those. It doesn't see clicks in WrangURL's own windows, but links
/// opened from there are handled straight away, while the keys are still held.
@MainActor
final class ClickModifierTracker {
    private(set) var lastClick: ModifierClick?
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] event in
            let type = event.type
            let keys = ModifierKeys(event.modifierFlags)
            let time = event.timestamp
            MainActor.assumeIsolated {
                self?.record(type: type, keys: keys, time: time)
            }
        }
    }

    private func record(type: NSEvent.EventType, keys: ModifierKeys, time: TimeInterval) {
        // Apps open links on mouse down or mouse up. Keep the keys from both halves of the click,
        // in case some were released in between.
        if type == .leftMouseUp, let down = lastClick {
            lastClick = ModifierClick(keys: down.keys.union(keys), time: time)
        } else {
            lastClick = ModifierClick(keys: keys, time: time)
        }
    }
}
