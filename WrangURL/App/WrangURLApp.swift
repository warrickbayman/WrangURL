import SwiftUI

@main
struct WrangURLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .appEnvironment(appDelegate)
        } label: {
            MenuBarLabel()
                .appEnvironment(appDelegate)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About WrangURL") { WrangURLHelp.showAboutPanel() }
            }
            CommandGroup(replacing: .help) {
                Button("WrangURL Help") { WrangURLHelp.open() }
                    .keyboardShortcut("?")
            }
        }
    }
}

enum WrangURLHelp {
    static let url = URL(string: "https://warrickbayman.github.io/WrangURL/")!

    @MainActor static func open() {
        NSWorkspace.shared.open(url)
    }

    /// The standard About panel, with a link to the help site as its credits.
    @MainActor static func showAboutPanel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let credits = NSAttributedString(string: "WrangURL Help", attributes: [
            .link: url,
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .paragraphStyle: paragraph,
        ])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate()
    }
}

extension View {
    func appEnvironment(_ app: AppDelegate) -> some View {
        environment(app.config)
            .environment(app.browsers)
            .environment(app.router)
            .environment(app.defaultBrowser)
            .environment(app.loginItem)
            .environment(app.updates)
            .environment(app.settingsWindow)
            .environment(app.historyWindow)
            .environment(app.onboardingWindow)
            .environment(app.history)
    }
}
