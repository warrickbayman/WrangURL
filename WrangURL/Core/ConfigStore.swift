import Foundation
import Observation
import os

/// Loads and saves `Config` as JSON in Application Support.
@MainActor
@Observable
final class ConfigStore {
    private(set) var config: Config
    @ObservationIgnored let fileURL: URL

    nonisolated private static let logger = Logger(subsystem: "com.thepublicgood.wrangurl", category: "config")

    /// Inside the sandbox this resolves to the app's container.
    nonisolated static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "WrangURL", directoryHint: .isDirectory)
            .appending(path: "config.json")
    }

    init(fileURL: URL = ConfigStore.defaultFileURL) {
        self.fileURL = fileURL
        config = Self.load(from: fileURL)
    }

    func update(_ change: (inout Config) -> Void) {
        var updated = config
        change(&updated)
        guard updated != config else { return }
        config = updated
        do {
            try Self.write(config, to: fileURL)
        } catch {
            Self.logger.error("Failed to save config: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns defaults when the file is missing. An unreadable file is moved aside
    /// rather than overwritten, so the user's rules are never silently lost.
    nonisolated static func load(from url: URL) -> Config {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Config.self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return Config()
        } catch {
            logger.error("Failed to read config: \(error.localizedDescription, privacy: .public)")
            backUpUnreadableFile(at: url)
            return Config()
        }
    }

    nonisolated static func write(_ config: Config, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url, options: .atomic)
    }

    nonisolated private static func backUpUnreadableFile(at url: URL) {
        let stamp = Int(Date.now.timeIntervalSince1970)
        let backup = url.deletingPathExtension().appendingPathExtension("corrupt-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: url, to: backup)
            logger.notice("Moved unreadable config to \(backup.path, privacy: .public)")
        } catch {
            logger.error("Failed to back up unreadable config: \(error.localizedDescription, privacy: .public)")
        }
    }
}
