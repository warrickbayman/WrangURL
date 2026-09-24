import SwiftUI

@main
struct WrangURLApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("WrangURL", systemImage: "arrow.triangle.branch") {
            MenuBarView(
                config: appDelegate.config,
                browsers: appDelegate.browsers,
                router: appDelegate.router,
                defaultBrowser: appDelegate.defaultBrowser
            )
        }
    }
}
