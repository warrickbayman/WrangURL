import Foundation

/// The history entries from one calendar day, newest first.
struct HistoryDay: Identifiable, Equatable {
    let date: Date
    let entries: [HistoryEntry]

    var id: Date { date }
}

extension [HistoryEntry] {
    /// Groups entries by the local calendar day they happened on, newest day first.
    func groupedByDay(calendar: Calendar = .current) -> [HistoryDay] {
        Dictionary(grouping: self) { calendar.startOfDay(for: $0.date) }
            .map { HistoryDay(date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }
}
