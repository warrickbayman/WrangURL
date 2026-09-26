import Foundation

/// One URL that WrangURL opened.
struct HistoryEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    let url: URL
    let date: Date
    let browserID: String
    let browserName: String
    let ruleName: String?
}

extension [HistoryEntry] {
    /// Entries whose URL, browser or rule contains `query`, ignoring case and diacritics.
    /// A blank query matches everything.
    func matching(_ query: String) -> [HistoryEntry] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return self }
        return filter { entry in
            [entry.url.absoluteString, entry.browserName, entry.ruleName ?? ""]
                .contains { $0.localizedStandardContains(query) }
        }
    }
}
