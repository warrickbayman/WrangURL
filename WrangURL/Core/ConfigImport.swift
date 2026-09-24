import Foundation

enum ConfigImportMode {
    /// Replace all rules and settings with the imported ones.
    case replace
    /// Keep current settings and add the imported rules after the existing ones.
    case addRules
}

enum ConfigImportError: LocalizedError, Equatable {
    case notAConfig

    var errorDescription: String? {
        switch self {
        case .notAConfig: "The file isn't a WrangURL configuration."
        }
    }
}

extension Config {
    /// Decodes an exported config. Stricter than loading our own file: the tolerant
    /// decoder would accept any JSON object (e.g. `{}`) and silently wipe the rules.
    static func decodeForImport(_ data: Data) throws -> Config {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["rules"] != nil || object["settings"] != nil,
              let config = try? JSONDecoder().decode(Config.self, from: data) else {
            throw ConfigImportError.notAConfig
        }
        return config
    }

    func importing(_ imported: Config, mode: ConfigImportMode) -> Config {
        switch mode {
        case .replace:
            var result = imported
            result.version = Config.currentVersion
            // Importing doesn't mean the user needs the setup assistant again.
            result.settings.hasCompletedOnboarding = settings.hasCompletedOnboarding
            return result
        case .addRules:
            var result = self
            var ids = Set(rules.map(\.id))
            for var rule in imported.rules {
                if !ids.insert(rule.id).inserted {
                    rule.id = UUID()
                    ids.insert(rule.id)
                }
                result.rules.append(rule)
            }
            return result
        }
    }
}
