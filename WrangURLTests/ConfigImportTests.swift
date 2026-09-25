import Foundation
import Testing
@testable import WrangURL

struct ConfigImportTests {
    private let chrome = "com.google.Chrome"
    private let safari = "com.apple.Safari"

    private func config(rules: [Rule], fallback: String? = nil, onboarded: Bool = true) -> Config {
        var config = Config()
        config.rules = rules
        config.settings.fallbackBrowserID = fallback
        config.settings.hasCompletedOnboarding = onboarded
        return config
    }

    @Test func rejectsJSONThatIsNotAConfig() {
        #expect(throws: ConfigImportError.notAConfig) { try Config.decodeForImport(Data("{}".utf8)) }
        #expect(throws: ConfigImportError.notAConfig) { try Config.decodeForImport(Data("[1, 2]".utf8)) }
        #expect(throws: ConfigImportError.notAConfig) { try Config.decodeForImport(Data("not json".utf8)) }
        #expect(throws: ConfigImportError.notAConfig) { try Config.decodeForImport(Data(#"{"rules": [{"name": "no pattern"}]}"#.utf8)) }
    }

    @Test func acceptsExportedConfig() throws {
        let original = config(rules: [Rule(name: "Local", pattern: "localhost", kind: .simple, browserIDs: [chrome])], fallback: safari)
        let encoder = JSONEncoder()
        let decoded = try Config.decodeForImport(encoder.encode(original))
        #expect(decoded == original)
    }

    @Test func replaceTakesImportedRulesAndSettingsButKeepsOnboardingState() {
        let current = config(rules: [Rule(name: "Old", pattern: "old.test", kind: .simple, browserIDs: [chrome])], fallback: chrome)
        let imported = config(
            rules: [Rule(name: "New", pattern: "new.test", kind: .simple, browserIDs: [safari])],
            fallback: safari,
            onboarded: false
        )

        let result = current.importing(imported, mode: .replace)
        #expect(result.rules.map(\.name) == ["New"])
        #expect(result.settings.fallbackBrowserID == safari)
        #expect(result.settings.hasCompletedOnboarding)
    }

    @Test func addRulesAppendsAndKeepsSettings() {
        let current = config(rules: [Rule(name: "Old", pattern: "old.test", kind: .simple, browserIDs: [chrome])], fallback: chrome)
        let imported = config(rules: [Rule(name: "New", pattern: "new.test", kind: .simple, browserIDs: [safari])], fallback: safari)

        let result = current.importing(imported, mode: .addRules)
        #expect(result.rules.map(\.name) == ["Old", "New"])
        #expect(result.settings.fallbackBrowserID == chrome)
    }

    @Test func addRulesGivesDuplicateIDsNewOnes() {
        let rule = Rule(name: "Same", pattern: "same.test", kind: .simple, browserIDs: [chrome])
        let current = config(rules: [rule])

        let result = current.importing(config(rules: [rule]), mode: .addRules)
        #expect(result.rules.count == 2)
        #expect(Set(result.rules.map(\.id)).count == 2)
    }
}
