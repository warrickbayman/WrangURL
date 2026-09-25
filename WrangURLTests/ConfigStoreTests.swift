import Foundation
import Testing
@testable import WrangURL

struct ConfigStoreTests {
    private let directory: URL
    private let fileURL: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "WrangURLTests-\(UUID().uuidString)")
        fileURL = directory.appending(path: "config.json")
    }

    @Test func missingFileLoadsDefaults() {
        #expect(ConfigStore.load(from: fileURL) == Config())
    }

    @Test func roundTrip() throws {
        var config = Config()
        config.settings = AppSettings(fallbackBrowserID: "com.apple.Safari", unmatchedBehavior: .showPicker)
        config.rules = [Rule(name: "Local", pattern: "localhost", kind: .simple, browserIDs: ["com.google.Chrome"])]

        try ConfigStore.write(config, to: fileURL)
        #expect(ConfigStore.load(from: fileURL) == config)
    }

    @Test func missingKeysUseDefaults() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"rules":[{"pattern":"localhost"}]}"#.utf8).write(to: fileURL)

        let config = ConfigStore.load(from: fileURL)
        #expect(config.settings == AppSettings())
        #expect(!config.settings.hasCompletedOnboarding)
        #expect(config.settings.logsURLs)
        let rule = try #require(config.rules.first)
        #expect(rule.kind == .simple)
        #expect(rule.isEnabled)
        #expect(rule.browserIDs.isEmpty)
    }

    @Test func corruptFileIsBackedUpNotOverwritten() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fileURL)

        #expect(ConfigStore.load(from: fileURL) == Config())
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(backups.contains { $0.hasPrefix("config.corrupt-") })
    }

    @MainActor
    @Test func updatePersists() {
        let store = ConfigStore(fileURL: fileURL)
        store.update { $0.settings.fallbackBrowserID = "com.apple.Safari" }
        #expect(ConfigStore.load(from: fileURL).settings.fallbackBrowserID == "com.apple.Safari")
    }
}

struct BrowserLocationTests {
    private let home = URL(filePath: "/Users/tester", directoryHint: .isDirectory)

    @Test(arguments: [
        "/Applications/Google Chrome.app",
        "/Applications/Setapp/Some Browser.app",
        "/Users/tester/Applications/Firefox.app",
        "/System/Volumes/Preboot/Cryptexes/App/System/Applications/Safari.app",
    ])
    func userFacingLocations(_ path: String) {
        #expect(BrowserRegistry.isUserFacing(URL(filePath: path), home: home))
    }

    @Test(arguments: [
        "/Users/tester/Library/Caches/ms-playwright/chromium-1223/chrome-mac-arm64/Google Chrome for Testing.app",
        "/Users/tester/Library/Developer/Xcode/DerivedData/Foo/Build/Products/Debug/Foo.app",
        "/Volumes/Stuff/build/Debug/WrangURL.app",
    ])
    func hiddenLocations(_ path: String) {
        #expect(!BrowserRegistry.isUserFacing(URL(filePath: path), home: home))
    }
}
