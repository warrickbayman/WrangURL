import AppKit
import UniformTypeIdentifiers
import os

/// Export and import of the whole configuration, via the standard file panels.
@MainActor
enum ConfigTransfer {
    private static let logger = Logger(subsystem: "com.thepublicgood.wrangurl", category: "config")

    static func export(_ store: ConfigStore) {
        let panel = NSSavePanel()
        panel.title = "Export Rules and Settings"
        panel.nameFieldStringValue = "WrangURL Config.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try ConfigStore.write(store.config, to: url)
        } catch {
            logger.error("Export failed: \(error.localizedDescription, privacy: .public)")
            showError("Couldn't export the configuration.", error)
        }
    }

    static func `import`(into store: ConfigStore) {
        let panel = NSOpenPanel()
        panel.title = "Import Rules and Settings"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let imported: Config
        do {
            imported = try Config.decodeForImport(Data(contentsOf: url))
        } catch {
            logger.error("Import failed: \(error.localizedDescription, privacy: .public)")
            showError("Couldn't import “\(url.lastPathComponent)”.", error)
            return
        }

        guard let mode = askImportMode(ruleCount: imported.rules.count, currentRuleCount: store.config.rules.count) else { return }
        store.update { $0 = $0.importing(imported, mode: mode) }
    }

    private static func askImportMode(ruleCount: Int, currentRuleCount: Int) -> ConfigImportMode? {
        // Nothing to lose; replacing also brings in the imported settings.
        guard currentRuleCount > 0 else { return .replace }

        let alert = NSAlert()
        alert.messageText = "Import \(ruleCount) \(ruleCount == 1 ? "rule" : "rules")?"
        alert.informativeText = "Replace your \(currentRuleCount) current \(currentRuleCount == 1 ? "rule" : "rules") and settings, or add the imported rules after your existing ones and keep your settings."
        alert.addButton(withTitle: "Add Rules")
        alert.addButton(withTitle: "Replace All")
        alert.addButton(withTitle: "Cancel")
        alert.buttons[1].hasDestructiveAction = true

        switch alert.runModal() {
        case .alertFirstButtonReturn: return .addRules
        case .alertSecondButtonReturn: return .replace
        default: return nil
        }
    }

    private static func showError(_ message: String, _ error: any Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
