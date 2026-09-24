import Foundation
import Testing
@testable import WrangURL

struct URLUserInputTests {
    @Test func addsHTTPSWhenSchemeMissing() {
        #expect(URL(userInput: "example.com/path")?.absoluteString == "https://example.com/path")
        #expect(URL(userInput: "  localhost:3000 ")?.absoluteString == "https://localhost:3000")
    }

    @Test func keepsExplicitScheme() {
        #expect(URL(userInput: "http://localhost")?.absoluteString == "http://localhost")
    }

    @Test(arguments: ["", "   ", "not a url", "https://"])
    func rejectsInvalidInput(_ input: String) {
        #expect(URL(userInput: input) == nil)
    }
}

struct RuleDisplayNameTests {
    @Test func fallsBackToPattern() {
        #expect(Rule(name: " ", pattern: "localhost", kind: .simple, browserIDs: []).displayName == "localhost")
        #expect(Rule(name: "Dev", pattern: "localhost", kind: .simple, browserIDs: []).displayName == "Dev")
    }
}
