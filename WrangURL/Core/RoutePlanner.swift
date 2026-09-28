import Foundation

enum RouteDecision: Equatable {
    case open(browserID: String)
    case pick(browserIDs: [String])
    case noBrowserAvailable
}

/// Decides where a URL goes. Pure, so the routing policy can be tested without AppKit.
struct RoutePlanner {
    static let lastResortBrowserID = "com.apple.Safari"

    var settings: AppSettings
    /// User-facing installed browsers, in display order.
    var installedBrowserIDs: [String]
    /// Whether a browser can be launched. Must return false for WrangURL itself.
    var isAvailable: (String) -> Bool

    /// The configured fallback, else Safari, else the first installed browser.
    var fallbackBrowserID: String? {
        [settings.fallbackBrowserID, Self.lastResortBrowserID]
            .compactMap { $0 }
            .first(where: isAvailable)
            ?? installedBrowserIDs.first(where: isAvailable)
    }

    /// - Parameter heldModifiers: The modifier keys held when the URL arrived. If they are
    ///   exactly `settings.pickerModifiers`, the picker offers every browser.
    func decide(for url: URL, matchedRule: Rule?, heldModifiers: ModifierKeys = []) -> RouteDecision {
        // Local HTML files arrive via the document type; rules only apply to web URLs.
        let ruleBrowserIDs = url.isFileURL ? nil : matchedRule.map { availableBrowserIDs($0.browserIDs) }

        if !settings.pickerModifiers.isEmpty && heldModifiers == settings.pickerModifiers {
            // The rule's browsers first, or else the fallback, then every other browser.
            let preferred = ruleBrowserIDs.flatMap { $0.isEmpty ? nil : $0 } ?? [fallbackBrowserID].compactMap { $0 }
            return openOrPick(availableBrowserIDs(preferred + installedBrowserIDs))
        }

        if url.isFileURL {
            return openFallback()
        }

        if let browserIDs = ruleBrowserIDs {
            return browserIDs.isEmpty ? openFallback() : openOrPick(browserIDs)
        }

        switch settings.unmatchedBehavior {
        case .openFallback:
            return openFallback()
        case .showPicker:
            var browserIDs = installedBrowserIDs.filter(isAvailable)
            if let fallback = fallbackBrowserID {
                browserIDs.removeAll { $0 == fallback }
                browserIDs.insert(fallback, at: 0)
            }
            return openOrPick(browserIDs)
        }
    }

    /// The available browsers among `browserIDs`, without duplicates, in their original order.
    private func availableBrowserIDs(_ browserIDs: [String]) -> [String] {
        var seen = Set<String>()
        return browserIDs.filter { isAvailable($0) && seen.insert($0).inserted }
    }

    private func openOrPick(_ browserIDs: [String]) -> RouteDecision {
        switch browserIDs.count {
        case 0: .noBrowserAvailable
        case 1: .open(browserID: browserIDs[0])
        default: .pick(browserIDs: browserIDs)
        }
    }

    private func openFallback() -> RouteDecision {
        fallbackBrowserID.map { .open(browserID: $0) } ?? .noBrowserAvailable
    }
}
