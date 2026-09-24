import SwiftUI

struct MenuBarView: View {
    @Environment(ConfigStore.self) private var config
    @Environment(BrowserRegistry.self) private var browsers
    @Environment(URLRouter.self) private var router
    @Environment(DefaultBrowserManager.self) private var defaultBrowser
    @Environment(LoginItemManager.self) private var loginItem
    @Environment(UpdateManager.self) private var updates
    @Environment(SettingsWindowController.self) private var settingsWindow

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
                Label {
                    Text(browser.name)
                } icon: {
                    if let icon = browsers.menuIcon(forID: browser.id) {
                        Image(nsImage: icon)
                    }
                }
                .tag(Optional(browser.id))
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

        Button("Edit Rules…") { settingsWindow.show(tab: .rules) }
        Button("Settings…") { settingsWindow.show(tab: .general) }
            .keyboardShortcut(",")
        Toggle("Open at Login", isOn: Binding(
            get: { loginItem.isEnabled },
            set: { loginItem.setEnabled($0) }
        ))

        Button("Check for Updates…") { updates.checkForUpdates() }
            .disabled(!updates.canCheckForUpdates)

        Divider()

        Button("Quit WrangURL") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
        .onAppear {
            defaultBrowser.refresh()
            browsers.refresh()
            loginItem.refresh()
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

/// The menubar icon. Shows a warning when WrangURL isn't the default browser,
/// since links then bypass it silently.
struct MenuBarLabel: View {
    @Environment(DefaultBrowserManager.self) private var defaultBrowser

    var body: some View {
        Image(systemName: defaultBrowser.isDefault ? "arrow.triangle.branch" : "exclamationmark.triangle")
            .accessibilityLabel(defaultBrowser.isDefault ? "WrangURL" : "WrangURL is not the default browser")
    }
}

private extension String {
    func truncated(to length: Int) -> String {
        count > length ? prefix(length - 1) + "…" : self
    }
}
