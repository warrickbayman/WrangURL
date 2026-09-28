import Foundation
import Testing
@testable import WrangURL

struct RoutePlannerTests {
    private let safari = "com.apple.Safari"
    private let chrome = "com.google.Chrome"
    private let firefox = "org.mozilla.firefox"
    private let missing = "com.example.Uninstalled"
    private let web = URL(string: "https://example.com")!

    private func planner(
        fallback: String? = "com.google.Chrome",
        unmatched: UnmatchedBehavior = .openFallback,
        installed: [String]? = nil
    ) -> RoutePlanner {
        let installed = installed ?? [chrome, firefox, safari]
        return RoutePlanner(
            settings: AppSettings(fallbackBrowserID: fallback, unmatchedBehavior: unmatched),
            installedBrowserIDs: installed,
            isAvailable: { installed.contains($0) }
        )
    }

    private func rule(_ browserIDs: [String]) -> Rule {
        Rule(name: "Test", pattern: "example.com", kind: .simple, browserIDs: browserIDs)
    }

    @Test func singleBrowserRuleOpensDirectly() {
        #expect(planner().decide(for: web, matchedRule: rule([firefox])) == .open(browserID: firefox))
    }

    @Test func multiBrowserRuleShowsPickerInRuleOrder() {
        #expect(planner().decide(for: web, matchedRule: rule([safari, firefox])) == .pick(browserIDs: [safari, firefox]))
    }

    @Test func uninstalledAndDuplicateBrowsersAreDropped() {
        #expect(planner().decide(for: web, matchedRule: rule([missing, firefox, firefox])) == .open(browserID: firefox))
    }

    @Test func ruleWithNoAvailableBrowsersUsesFallback() {
        #expect(planner().decide(for: web, matchedRule: rule([missing])) == .open(browserID: chrome))
        #expect(planner().decide(for: web, matchedRule: rule([])) == .open(browserID: chrome))
    }

    @Test func unmatchedOpensFallback() {
        #expect(planner().decide(for: web, matchedRule: nil) == .open(browserID: chrome))
    }

    @Test func unmatchedPickerListsAllBrowsersWithFallbackFirst() {
        let decision = planner(fallback: firefox, unmatched: .showPicker).decide(for: web, matchedRule: nil)
        #expect(decision == .pick(browserIDs: [firefox, chrome, safari]))
    }

    @Test func unmatchedPickerWithOneBrowserOpensIt() {
        let decision = planner(fallback: nil, unmatched: .showPicker, installed: [safari]).decide(for: web, matchedRule: nil)
        #expect(decision == .open(browserID: safari))
    }

    @Test func missingFallbackFallsBackToSafari() {
        #expect(planner(fallback: missing).fallbackBrowserID == safari)
        #expect(planner(fallback: nil).fallbackBrowserID == safari)
    }

    @Test func missingFallbackAndSafariUsesFirstInstalled() {
        #expect(planner(fallback: nil, installed: [firefox, chrome]).fallbackBrowserID == firefox)
    }

    @Test func noBrowsersAtAll() {
        #expect(planner(fallback: nil, installed: []).decide(for: web, matchedRule: nil) == .noBrowserAvailable)
    }

    @Test func fileURLsIgnoreRulesAndUseFallback() {
        let file = URL(filePath: "/tmp/page.html")
        #expect(planner(unmatched: .showPicker).decide(for: file, matchedRule: rule([firefox])) == .open(browserID: chrome))
    }

    // MARK: Picker modifiers (default ⌥⌘)

    private let forced: ModifierKeys = [.option, .command]

    @Test func modifiersShowPickerWithRuleBrowsersFirst() {
        let decision = planner().decide(for: web, matchedRule: rule([safari, missing]), heldModifiers: forced)
        #expect(decision == .pick(browserIDs: [safari, chrome, firefox]))
    }

    @Test func modifiersShowPickerWithFallbackFirstWhenUnmatched() {
        let decision = planner(fallback: firefox).decide(for: web, matchedRule: nil, heldModifiers: forced)
        #expect(decision == .pick(browserIDs: [firefox, chrome, safari]))
    }

    @Test func modifiersShowPickerForFileURLs() {
        let file = URL(filePath: "/tmp/page.html")
        let decision = planner().decide(for: file, matchedRule: rule([firefox]), heldModifiers: forced)
        #expect(decision == .pick(browserIDs: [chrome, firefox, safari]))
    }

    @Test func modifiersMustMatchExactly() {
        let single = rule([firefox])
        #expect(planner().decide(for: web, matchedRule: single, heldModifiers: [.option]) == .open(browserID: firefox))
        #expect(planner().decide(for: web, matchedRule: single, heldModifiers: [.option, .command, .shift]) == .open(browserID: firefox))
    }

    @Test func emptyPickerModifiersTurnTheShortcutOff() {
        var planner = planner()
        planner.settings.pickerModifiers = []
        #expect(planner.decide(for: web, matchedRule: rule([firefox]), heldModifiers: []) == .open(browserID: firefox))
    }

    @Test func modifiersWithOneBrowserOpenIt() {
        let decision = planner(fallback: nil, installed: [safari]).decide(for: web, matchedRule: nil, heldModifiers: forced)
        #expect(decision == .open(browserID: safari))
    }

    @Test func pickerModifiersRoundTripAsKeyNames() throws {
        var settings = AppSettings()
        settings.pickerModifiers = [.command, .shift]
        let data = try JSONEncoder().encode(settings)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["pickerModifiers"] as? [String] == ["shift", "command"])
        #expect(try JSONDecoder().decode(AppSettings.self, from: data).pickerModifiers == [.shift, .command])
    }

    @Test func pickerModifiersDefaultToOptionCommandAndIgnoreUnknownKeys() throws {
        let missing = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(missing.pickerModifiers == [.option, .command])
        let unknown = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"pickerModifiers": ["option", "hyper"]}"#.utf8))
        #expect(unknown.pickerModifiers == [.option])
    }

    // MARK: Keys held for the click that opened a link

    @Test func recentClickKeysCountAfterRelease() {
        let click = ModifierClick(keys: [.option, .command], time: 100)
        #expect(ModifierKeys.forLink(heldNow: [], lastClick: click, now: 101.5) == [.option, .command])
    }

    @Test func staleClickIsIgnored() {
        let click = ModifierClick(keys: [.option, .command], time: 100)
        #expect(ModifierKeys.forLink(heldNow: [], lastClick: click, now: 102.5) == [])
    }

    @Test func plainClickLeavesHeldKeys() {
        // A link opened from the keyboard just after an ordinary click.
        let click = ModifierClick(keys: [], time: 100)
        #expect(ModifierKeys.forLink(heldNow: [.option, .command], lastClick: click, now: 100.5) == [.option, .command])
    }

    @Test func heldKeysCountWithoutAClick() {
        #expect(ModifierKeys.forLink(heldNow: [.shift], lastClick: nil, now: 100) == [.shift])
    }
}
