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
            .environment(app.onboardingWindow)
    }
}
