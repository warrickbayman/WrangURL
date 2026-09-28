import Foundation

/// A combination of modifier keys. AppKit-free so it can live in `AppSettings`;
/// `URLRouter` converts `NSEvent.ModifierFlags` into it.
struct ModifierKeys: OptionSet, Hashable, Sendable {
    let rawValue: Int

    static let control = ModifierKeys(rawValue: 1 << 0)
    static let option = ModifierKeys(rawValue: 1 << 1)
    static let shift = ModifierKeys(rawValue: 1 << 2)
    static let command = ModifierKeys(rawValue: 1 << 3)

    private struct Key {
        let key: ModifierKeys
        let symbol: String
        let name: String
    }

    /// Keys in the order macOS displays them, with their symbol and config name.
    private static let keys = [
        Key(key: .control, symbol: "⌃", name: "control"),
        Key(key: .option, symbol: "⌥", name: "option"),
        Key(key: .shift, symbol: "⇧", name: "shift"),
        Key(key: .command, symbol: "⌘", name: "command"),
    ]

    /// The keys as symbols, for example "⌥⌘". Empty when no key is set.
    var symbols: String {
        Self.keys.filter { contains($0.key) }.map(\.symbol).joined()
    }
}

/// Encoded as a list of key names, such as `["option", "command"]`, so `config.json`
/// stays readable. Unknown names are ignored.
extension ModifierKeys: Codable {
    init(from decoder: any Decoder) throws {
        let names = try decoder.singleValueContainer().decode([String].self)
        self = Self.keys.reduce(into: []) { result, entry in
            if names.contains(entry.name) {
                result.insert(entry.key)
            }
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.keys.filter { contains($0.key) }.map(\.name))
    }
}
