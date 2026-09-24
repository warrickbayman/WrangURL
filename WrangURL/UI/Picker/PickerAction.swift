import AppKit

/// Keyboard commands understood by the browser picker.
enum PickerAction: Equatable {
    /// Choose the browser at a zero-based index (keys 1–9).
    case choose(index: Int)
    case chooseSelected
    case moveSelection(by: Int)
    case copyURL
    case cancel

    private enum KeyCode {
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let escape: UInt16 = 53
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
        static let tab: UInt16 = 48
    }

    init?(keyCode: UInt16, characters: String?, modifiers: NSEvent.ModifierFlags) {
        let modifiers = modifiers.intersection(.deviceIndependentFlagsMask)

        if modifiers.contains(.command) {
            guard characters?.lowercased() == "c" else { return nil }
            self = .copyURL
            return
        }

        switch keyCode {
        case KeyCode.returnKey, KeyCode.keypadEnter:
            self = .chooseSelected
        case KeyCode.escape:
            self = .cancel
        case KeyCode.leftArrow, KeyCode.upArrow:
            self = .moveSelection(by: -1)
        case KeyCode.rightArrow, KeyCode.downArrow:
            self = .moveSelection(by: 1)
        case KeyCode.tab:
            self = .moveSelection(by: modifiers.contains(.shift) ? -1 : 1)
        default:
            guard let characters, characters.count == 1,
                  let digit = Int(characters), (1...9).contains(digit) else { return nil }
            self = .choose(index: digit - 1)
        }
    }
}
