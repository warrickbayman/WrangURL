import Foundation
import Observation
import os

/// Keeps the links WrangURL has opened, newest first, in `history.json` in Application Support.
@MainActor
@Observable
final class HistoryStore {
    private(set) var entries: [HistoryEntry]
    @ObservationIgnored let fileURL: URL
    /// The most entries kept; older ones are dropped.
    @ObservationIgnored let limit: Int

    nonisolated private static let logger = Logger(subsystem: "com.thepublicgood.wrangurl", category: "history")

    nonisolated static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "WrangURL", directoryHint: .isDirectory)
            .appending(path: "history.json")
    }

    init(fileURL: URL = HistoryStore.defaultFileURL, limit: Int = 5000) {
        self.fileURL = fileURL
        self.limit = limit
        entries = Self.load(from: fileURL)
    }

    func record(_ entry: HistoryEntry) {
        entries.insert(entry, at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
        save()
    }

    func remove(_ ids: Set<HistoryEntry.ID>) {
        entries.removeAll { ids.contains($0.id) }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func save() {
        do {
            try Self.write(entries, to: fileURL)
        } catch {
            Self.logger.error("Failed to save history: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated static func load(from url: URL) -> [HistoryEntry] {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([HistoryEntry].self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        } catch {
            logger.error("Failed to read history: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    nonisolated static func write(_ entries: [HistoryEntry], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(entries).write(to: url, options: .atomic)
    }
}
