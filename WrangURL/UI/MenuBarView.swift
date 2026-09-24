import SwiftUI

struct MenuBarView: View {
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

        Section("Recent Links") {
            if router.recent.isEmpty {
                Text("No links yet")
            } else {
                ForEach(router.recent) { entry in
                    Button("\(entry.url.absoluteString.truncated(to: 60)) → \(entry.targetName)") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.url.absoluteString, forType: .string)
                    }
                }
            }
        }

        Divider()

        Button("Quit WrangURL") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
        .onAppear { defaultBrowser.refresh() }
    }
}

private extension String {
    func truncated(to length: Int) -> String {
        count > length ? prefix(length - 1) + "…" : self
    }
}
