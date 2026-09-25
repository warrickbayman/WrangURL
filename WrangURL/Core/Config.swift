import Foundation

enum UnmatchedBehavior: String, Codable, CaseIterable, Sendable {
    /// Open URLs that match no rule in the fallback browser.
    case openFallback
    /// Show the picker with every installed browser.
    case showPicker
}

struct AppSettings: Codable, Equatable, Sendable {
    /// Bundle identifier of the fallback browser. `nil` until onboarding has run.
    var fallbackBrowserID: String?
    var unmatchedBehavior: UnmatchedBehavior = .openFallback
    var hasCompletedOnboarding = false
    /// Whether URLs appear in the system log. When off, they're replaced with a placeholder.
    var logsURLs = true
}

extension AppSettings {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fallbackBrowserID = try container.decodeIfPresent(String.self, forKey: .fallbackBrowserID)
        unmatchedBehavior = try container.decodeIfPresent(UnmatchedBehavior.self, forKey: .unmatchedBehavior) ?? .openFallback
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        logsURLs = try container.decodeIfPresent(Bool.self, forKey: .logsURLs) ?? true
    }
}

/// Everything persisted to `config.json`.
struct Config: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version = Config.currentVersion
    var settings = AppSettings()
    var rules: [Rule] = []
}

extension Config {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Config.currentVersion
        settings = try container.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        rules = try container.decodeIfPresent([Rule].self, forKey: .rules) ?? []
    }
}
