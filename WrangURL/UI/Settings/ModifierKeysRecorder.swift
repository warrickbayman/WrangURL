import AppKit
import SwiftUI

/// A field that records a combination of modifier keys. Click it, press the keys, and the
/// combination is saved when they're all released. Esc, clicking the field again, or
/// switching to another app cancels.
struct ModifierKeysRecorder: View {
    @Binding var keys: ModifierKeys
    @State private var recording = ModifierKeysRecording()

    var body: some View {
        HStack(spacing: 6) {
            Button {
                if recording.isRecording {
                    recording.stop()
                } else {
                    recording.start { keys = $0 }
                }
            } label: {
                Text(title)
                    .frame(minWidth: 120)
            }
            .help(recording.isRecording ? "Press the modifier keys, or Esc to cancel" : "Click, then press the modifier keys")

            if !keys.isEmpty && !recording.isRecording {
                Button {
                    keys = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Turn off")
                .accessibilityLabel("Turn off")
            }
        }
        .onDisappear { recording.stop() }
    }

    private var title: String {
        if recording.isRecording {
            return recording.held.isEmpty ? "Press keys…" : recording.held.symbols
        }
        return keys.isEmpty ? "Record Keys" : keys.symbols
    }
}

/// Watches key events in WrangURL's own windows while recording. A local monitor sees them
/// without Accessibility permission, because the Settings window is key.
@MainActor
@Observable
final class ModifierKeysRecording {
    private(set) var isRecording = false
    /// The keys held right now, shown while recording.
    private(set) var held: ModifierKeys = []

    /// Every key held since the first one was pressed, so releasing keys one at a time
    /// still records the whole combination.
    @ObservationIgnored private var combination: ModifierKeys = []
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var resignObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var onFinish: (@MainActor (ModifierKeys) -> Void)?

    private static let escapeKeyCode: UInt16 = 53

    func start(onFinish: @escaping @MainActor (ModifierKeys) -> Void) {
        stop()
        self.onFinish = onFinish
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            let type = event.type
            let flags = event.modifierFlags
            let keyCode = event.keyCode
            let consumed = MainActor.assumeIsolated {
                self?.handle(type: type, flags: flags, keyCode: keyCode) ?? false
            }
            return consumed ? nil : event
        }
        // Key events stop arriving once another app is active, so don't wait for them.
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
        resignObserver = nil
        onFinish = nil
        isRecording = false
        held = []
        combination = []
    }

    /// Returns whether the event is used up, so recording keys doesn't trigger shortcuts.
    private func handle(type: NSEvent.EventType, flags: NSEvent.ModifierFlags, keyCode: UInt16) -> Bool {
        switch type {
        case .flagsChanged:
            held = ModifierKeys(flags)
            combination.formUnion(held)
            if held.isEmpty && !combination.isEmpty {
                let finished = combination
                let onFinish = onFinish
                stop()
                onFinish?(finished)
            }
            return false
        case .keyDown:
            if keyCode == Self.escapeKeyCode {
                stop()
            }
            return true
        default:
            return false
        }
    }
}
