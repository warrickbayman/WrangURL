import Foundation
import Testing
@testable import WrangURL

struct SourceAppTests {
    @Test(arguments: [
        ("/Applications/Slack.app", "/Applications/Slack.app"),
        ("/Applications/Slack.app/Contents/Frameworks/Slack Helper.app", "/Applications/Slack.app"),
        (
            "/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/com.apple.WebKit.WebContent.xpc",
            nil
        ),
        ("/Users/me/Applications/Tools/Mail Helper.APP/Contents/MacOS/x", "/Users/me/Applications/Tools/Mail Helper.APP"),
        ("/usr/bin/open", nil),
    ] as [(String, String?)])
    func containingAppIsOutermostAppBundle(path: String, expected: String?) {
        let url = URL(filePath: path)
        #expect(SourceApp.containingAppURL(of: url)?.path == expected)
    }
}
