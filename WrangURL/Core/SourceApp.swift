import Foundation

/// The app a link was clicked in.
struct SourceApp: Codable, Hashable, Sendable {
    /// Bundle identifier.
    let id: String
    let name: String
}

extension SourceApp {
    /// The outermost `.app` bundle in `url`'s path, e.g. `/Applications/Slack.app` for
    /// `/Applications/Slack.app/Contents/Frameworks/Slack Helper.app`.
    nonisolated static func containingAppURL(of url: URL) -> URL? {
        var appURL: URL?
        var current = url.standardizedFileURL
        while current.pathComponents.count > 1 {
            if current.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
                appURL = current
            }
            current = current.deletingLastPathComponent()
        }
        return appURL
    }
}
