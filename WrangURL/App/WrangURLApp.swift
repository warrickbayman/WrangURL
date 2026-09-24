import SwiftUI

@main
struct WrangURLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("WrangURL", systemImage: "arrow.triangle.branch") {
            MenuBarView()
                .appEnvironment(appDelegate)
        }
    }
}

extension View {
    func appEnvironment(_ app: AppDelegate) -> some View {
        environment(app.config)
            .environment(app.browsers)
            .environment(app.router)
            .environment(app.defaultBrowser)
            .environment(app.settingsWindow)
    }
}
