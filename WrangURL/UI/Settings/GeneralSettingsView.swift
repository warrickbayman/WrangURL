import SwiftUI

struct GeneralSettingsView: View {
    @Environment(ConfigStore.self) private var config
    @Environment(BrowserRegistry.self) private var browsers
    @Environment(DefaultBrowserManager.self) private var defaultBrowser
    @Environment(URLRouter.self) private var router
    @Environment(LoginItemManager.self) private var loginItem
    @Environment(UpdateManager.self) private var updates
    @Environment(OnboardingWindowController.self) private var onboarding
    @Environment(HistoryWindowController.self) private var historyWindow

    var body: some View {
        Form {
            Section("Default Browser") {
                if defaultBrowser.isDefault {
                    Label("WrangURL is your default browser", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    LabeledContent {
                        Button("Set as Default Browser…") {
                            Task { await defaultBrowser.makeDefault() }
                        }
                    } label: {
                        Label("WrangURL is not your default browser", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Links from other apps won't be routed until it is.")
                    }
                }
                if let error = defaultBrowser.lastError {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section {
                Picker("Fallback browser", selection: fallbackBrowserID) {
                    Text("Automatic (\(automaticFallbackName))").tag(String?.none)
                    Divider()
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

                Picker("When no rule matches", selection: unmatchedBehavior) {
                    Text("Open in the fallback browser").tag(UnmatchedBehavior.openFallback)
                    Text("Ask which browser to use").tag(UnmatchedBehavior.showPicker)
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Routing")
            } footer: {
                Text("The fallback browser also opens local HTML files and links whose rule has no installed browser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Open WrangURL at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                if loginItem.requiresApproval {
                    LoginItemApprovalNote()
                }
                if let error = loginItem.lastError {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updates.automaticallyChecksForUpdates },
                    set: { updates.automaticallyChecksForUpdates = $0 }
                ))
                LabeledContent("Version \(updates.currentVersion)") {
                    Button("Check Now") { updates.checkForUpdates() }
                        .disabled(!updates.canCheckForUpdates)
                }
            }

            Section {
                Toggle("Include URLs in logs", isOn: logsURLs)
                LabeledContent {
                    Button("Show History…") { historyWindow.show() }
                } label: {
                    Toggle("Keep a history of opened links", isOn: keepsHistory)
                }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Logged links help troubleshoot rules. History stays on this Mac; turning it off keeps existing entries.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Configuration") {
                LabeledContent("Config file") {
                    HStack {
                        Button("Reveal in Finder") {
                            config.ensureFileExists()
                            NSWorkspace.shared.activateFileViewerSelecting([config.fileURL])
                        }
                        Button("Reload") {
                            config.reload()
                        }
                        .help("Re-read the file after editing it by hand")
                    }
                }
                LabeledContent("Rules and settings") {
                    HStack {
                        Button("Import…") { ConfigTransfer.import(into: config) }
                        Button("Export…") { ConfigTransfer.export(config) }
                    }
                }
                LabeledContent("Setup assistant") {
                    Button("Run Setup Again…") { onboarding.show() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 680, height: 580)
    }

    private var automaticFallbackName: String {
        var planner = router.planner
        planner.settings.fallbackBrowserID = nil
        return planner.fallbackBrowserID.map(browsers.name(forID:)) ?? "none"
    }

    private var fallbackBrowserID: Binding<String?> {
        Binding(
            get: { config.config.settings.fallbackBrowserID },
            set: { id in config.update { $0.settings.fallbackBrowserID = id } }
        )
    }

    private var logsURLs: Binding<Bool> {
        Binding(
            get: { config.config.settings.logsURLs },
            set: { enabled in config.update { $0.settings.logsURLs = enabled } }
        )
    }

    private var keepsHistory: Binding<Bool> {
        Binding(
            get: { config.config.settings.keepsHistory },
            set: { enabled in config.update { $0.settings.keepsHistory = enabled } }
        )
    }

    private var unmatchedBehavior: Binding<UnmatchedBehavior> {
        Binding(
            get: { config.config.settings.unmatchedBehavior },
            set: { behavior in config.update { $0.settings.unmatchedBehavior = behavior } }
        )
    }
}
