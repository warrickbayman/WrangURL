import SwiftUI

/// A browser's app icon, or a placeholder when it isn't installed.
struct BrowserIcon: View {
    @Environment(BrowserRegistry.self) private var browsers

    let id: String
    var size: CGFloat = 20

    var body: some View {
        if let icon = browsers.icon(forID: id) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
                .help(browsers.resolve(id)?.name ?? id)
        } else {
            Image(systemName: "questionmark.app.dashed")
                .resizable()
                .foregroundStyle(.secondary)
                .frame(width: size * 0.8, height: size * 0.8)
                .frame(width: size, height: size)
                .help("\(id) is not installed")
        }
    }
}

extension BrowserRegistry {
    func name(forID id: String) -> String {
        resolve(id)?.name ?? id
    }

    /// Human-readable outcome of routing a URL, for the URL testers.
    func describe(_ decision: RouteDecision) -> String {
        switch decision {
        case .open(let id):
            "Opens in \(name(forID: id))"
        case .pick(let ids):
            "Shows the picker: \(ids.map(name(forID:)).formatted(.list(type: .and)))"
        case .noBrowserAvailable:
            "No browser is available"
        }
    }
}
