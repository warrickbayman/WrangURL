import SwiftUI

struct MenuBarView: View {
    let config: ConfigStore
    let browsers: BrowserRegistry
    let router: URLRouter
    let defaultBrowser: DefaultBrowserManager

    var body: some View {
        if defaultBrowser.isDefault {
            Text("✓ WrangURL is the default browser")
        } else {
            Button("Set as Default Browser…") {
                Task { await defaultBrowser.makeDefault() }
            }
        }
        if let error = defaultBrowser.lastError {
            Text(error)
        }

        Divider()

        Picker("Fallback Browser", selection: fallbackBrowserID) {
            ForEach(browsers.browsers) { browser in
                Text(browser.name).tag(Optional(browser.id))
            }
        }
        Picker("When No Rule Matches", selection: unmatchedBehavior) {
            Text("Open in Fallback Browser").tag(UnmatchedBehavior.openFallback)
            Text("Ask Which Browser to Use").tag(UnmatchedBehavior.showPicker)
        }

        Divider()

        Section("Recent Links") {
            if router.recent.isEmpty {
                Text("No links yet")
            } else {
                ForEach(router.recent) { entry in
                    Button(recentTitle(for: entry)) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.url.absoluteString, forType: .string)
                    }
                }
            }
        }

        Divider()

        // Until the Settings window exists (milestone 5), rules are edited in config.json.
        Button("Reveal Config File") {
            config.ensureFileExists()
            NSWorkspace.shared.activateFileViewerSelecting([config.fileURL])
        }
        Button("Reload Config") {
            config.reload()
        }

        Divider()

        Button("Quit WrangURL") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
        .onAppear {
            defaultBrowser.refresh()
            browsers.refresh()
        }
    }

    private var fallbackBrowserID: Binding<String?> {
        Binding(
            get: { config.config.settings.fallbackBrowserID },
            set: { id in config.update { $0.settings.fallbackBrowserID = id } }
        )
    }

    private var unmatchedBehavior: Binding<UnmatchedBehavior> {
        Binding(
            get: { config.config.settings.unmatchedBehavior },
            set: { behavior in config.update { $0.settings.unmatchedBehavior = behavior } }
        )
    }

    private func recentTitle(for entry: URLRouter.Entry) -> String {
        let url = entry.url.absoluteString.truncated(to: 50)
        if let rule = entry.ruleName {
            return "\(url) → \(entry.targetName) (\(rule))"
        }
        return "\(url) → \(entry.targetName)"
    }
}

private extension String {
    func truncated(to length: Int) -> String {
        count > length ? prefix(length - 1) + "…" : self
    }
}
