import SwiftUI

/// Every URL WrangURL has opened, grouped by day.
struct HistoryView: View {
    @Environment(HistoryStore.self) private var history
    @Environment(URLRouter.self) private var router
    @Environment(ConfigStore.self) private var config

    @State private var query = ""
    @State private var selection: Set<HistoryEntry.ID> = []
    @State private var isConfirmingClear = false

    var body: some View {
        Group {
            if history.entries.isEmpty {
                ContentUnavailableView(
                    "No History",
                    systemImage: "clock",
                    description: Text(emptyDescription)
                )
            } else if days.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                list
            }
        }
        .frame(minWidth: 500, minHeight: 300)
        .searchable(text: $query, placement: .toolbar, prompt: "Search History")
        .toolbar {
            ToolbarItem {
                Button("Clear History…", systemImage: "trash") { isConfirmingClear = true }
                    .help("Clear History…")
                    .disabled(history.entries.isEmpty)
            }
        }
        .confirmationDialog("Clear all history?", isPresented: $isConfirmingClear) {
            Button("Clear History", role: .destructive) {
                history.clear()
                selection.removeAll()
            }
        } message: {
            Text("This removes all \(history.entries.count) links from the history. It can't be undone.")
        }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(days) { day in
                Section {
                    ForEach(day.entries) { entry in
                        HistoryRow(entry: entry)
                    }
                } header: {
                    Text(title(for: day.date))
                }
            }
        }
        .contextMenu(forSelectionType: HistoryEntry.ID.self) { ids in
            if !ids.isEmpty {
                Button(ids.count == 1 ? "Open Link" : "Open \(ids.count) Links") { open(ids) }
                Button(ids.count == 1 ? "Copy Link" : "Copy \(ids.count) Links") { copy(ids) }
                Divider()
                Button("Delete from History", role: .destructive) { delete(ids) }
            }
        } primaryAction: { ids in
            open(ids)
        }
        .onDeleteCommand { delete(selection) }
    }

    private var days: [HistoryDay] {
        history.entries.matching(query).groupedByDay()
    }

    private var emptyDescription: String {
        config.config.settings.keepsHistory
            ? "Links you open through WrangURL appear here."
            : "History is turned off in Settings → General."
    }

    private func title(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        return date.formatted(date: .complete, time: .omitted)
    }

    /// The selected entries in list order, which is newest first.
    private func entries(_ ids: Set<HistoryEntry.ID>) -> [HistoryEntry] {
        history.entries.filter { ids.contains($0.id) }
    }

    /// Opens the links again through the rules, as if they had just been clicked.
    private func open(_ ids: Set<HistoryEntry.ID>) {
        router.handle(entries(ids).map(\.url))
    }

    private func copy(_ ids: Set<HistoryEntry.ID>) {
        let links = entries(ids).map(\.url.absoluteString).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(links, forType: .string)
    }

    private func delete(_ ids: Set<HistoryEntry.ID>) {
        history.remove(ids)
        selection.subtract(ids)
    }
}

/// One opened link: time, URL and the browser it went to.
private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack {
            Text(entry.date, format: .dateTime.hour().minute())
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text(entry.url.absoluteString)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(entry.url.absoluteString)
            Spacer()
            if let rule = entry.ruleName {
                Text(rule)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            BrowserIcon(id: entry.browserID, size: 16)
            Text(entry.browserName)
        }
    }
}
