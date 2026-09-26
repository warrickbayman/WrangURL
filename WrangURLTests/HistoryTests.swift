import Foundation
import Testing
@testable import WrangURL

@MainActor
struct HistoryStoreTests {
    private let directory: URL
    private let fileURL: URL

    init() {
        directory = FileManager.default.temporaryDirectory.appending(path: "WrangURLTests-\(UUID().uuidString)")
        fileURL = directory.appending(path: "history.json")
    }

    @Test func missingFileLoadsEmpty() {
        #expect(HistoryStore.load(from: fileURL).isEmpty)
    }

    @Test func recordsNewestFirstAndPersists() {
        let store = HistoryStore(fileURL: fileURL)
        store.record(entry("https://a.example"))
        store.record(entry("https://b.example"))

        #expect(store.entries.map(\.url.host) == ["b.example", "a.example"])
        #expect(HistoryStore(fileURL: fileURL).entries == store.entries)
    }

    @Test func keepsRuleName() {
        let store = HistoryStore(fileURL: fileURL)
        store.record(entry("https://a.example", ruleName: "Work"))
        store.record(entry("https://b.example"))

        #expect(HistoryStore(fileURL: fileURL).entries.map(\.ruleName) == [nil, "Work"])
    }

    @Test func trimsToLimit() {
        let store = HistoryStore(fileURL: fileURL, limit: 3)
        for index in 1...5 {
            store.record(entry("https://\(index).example"))
        }

        #expect(store.entries.map(\.url.host) == ["5.example", "4.example", "3.example"])
        #expect(HistoryStore(fileURL: fileURL).entries.count == 3)
    }

    @Test func clearEmptiesAndPersists() {
        let store = HistoryStore(fileURL: fileURL)
        store.record(entry("https://a.example"))
        store.clear()

        #expect(store.entries.isEmpty)
        #expect(HistoryStore(fileURL: fileURL).entries.isEmpty)
    }

    @Test func removesOnlyGivenEntriesAndPersists() {
        let store = HistoryStore(fileURL: fileURL)
        for host in ["a", "b", "c"] {
            store.record(entry("https://\(host).example"))
        }
        let middle = store.entries[1]
        store.remove([middle.id])

        #expect(store.entries.map(\.url.host) == ["c.example", "a.example"])
        #expect(HistoryStore(fileURL: fileURL).entries == store.entries)
    }

    @Test func unreadableFileLoadsEmpty() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: fileURL)

        #expect(HistoryStore.load(from: fileURL).isEmpty)
    }

    /// Dates are whole seconds, because ISO 8601 in JSON drops fractions and the
    /// reloaded entries wouldn't compare equal otherwise.
    private func entry(_ url: String, ruleName: String? = nil) -> HistoryEntry {
        HistoryEntry(
            url: URL(string: url)!,
            date: Date(timeIntervalSince1970: 1_790_000_000),
            browserID: "com.apple.Safari",
            browserName: "Safari",
            ruleName: ruleName
        )
    }
}

struct HistoryGroupingTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Africa/Johannesburg")!
        return calendar
    }()

    @Test func emptyHistoryHasNoDays() {
        #expect([HistoryEntry]().groupedByDay(calendar: calendar).isEmpty)
    }

    @Test func groupsByLocalDayNewestFirst() throws {
        let morning = try entry(at: "2026-09-26T07:42:00Z")      // 09:42 on the 26th locally
        let justAfterMidnight = try entry(at: "2026-09-25T22:30:00Z") // 00:30 on the 26th locally, still the 25th in UTC
        let lateEvening = try entry(at: "2026-09-25T21:00:00Z")  // 23:00 on the 25th locally

        let days = [morning, justAfterMidnight, lateEvening].groupedByDay(calendar: calendar)

        #expect(days.count == 2)
        #expect(days.map(\.entries) == [[morning, justAfterMidnight], [lateEvening]])
        #expect(days.map { calendar.component(.day, from: $0.date) } == [26, 25])
    }

    @Test func daysAreNewestFirstEvenWhenEntriesAreNot() throws {
        let older = try entry(at: "2026-09-20T10:00:00Z")
        let newer = try entry(at: "2026-09-24T10:00:00Z")

        let days = [older, newer].groupedByDay(calendar: calendar)

        #expect(days.map(\.entries) == [[newer], [older]])
    }

    private func entry(at timestamp: String) throws -> HistoryEntry {
        HistoryEntry(
            url: URL(string: "https://example.com")!,
            date: try Date(timestamp, strategy: .iso8601),
            browserID: "com.apple.Safari",
            browserName: "Safari",
            ruleName: nil
        )
    }
}

struct HistorySearchTests {
    private let entries = [
        HistoryEntry(url: URL(string: "https://github.com/org/repo")!, date: .now, browserID: "com.google.Chrome", browserName: "Google Chrome", ruleName: "Work"),
        HistoryEntry(url: URL(string: "http://localhost:3000")!, date: .now, browserID: "org.mozilla.firefox", browserName: "Firefox", ruleName: nil),
    ]

    @Test(arguments: ["", "  "])
    func blankQueryMatchesEverything(query: String) {
        #expect(entries.matching(query) == entries)
    }

    @Test(arguments: [
        ("GITHUB", "github.com"),
        ("chrome", "github.com"),
        ("work", "github.com"),
        ("3000", "localhost"),
        ("firefox", "localhost"),
    ])
    func matchesURLBrowserOrRuleIgnoringCase(query: String, host: String) {
        #expect(entries.matching(query).map(\.url.host) == [host])
    }

    @Test func noMatchIsEmpty() {
        #expect(entries.matching("example.org").isEmpty)
    }
}
