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
}
