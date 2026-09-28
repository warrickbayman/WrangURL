import AppKit

extension ModifierKeys {
    /// The ⌃⌥⇧⌘ keys in `flags`. Caps Lock, Fn and the rest are ignored.
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.command) { insert(.command) }
    }
}
