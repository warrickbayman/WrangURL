import Foundation
import Testing
@testable import WrangURL

struct SimplePatternTests {
    private func matches(_ pattern: String, _ url: String) throws -> Bool {
        let regex = try RuleMatcher.compile(pattern, kind: .simple)
        return regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil
    }

    @Test(arguments: [
        "http://localhost",
        "https://localhost:3000/app",
        "http://LOCALHOST/",
        "http://localhost?q=1",
        "http://user@localhost/",
    ])
    func bareHostMatches(_ url: String) throws {
        #expect(try matches("localhost", url))
    }

    @Test(arguments: [
        "http://localhost.evil.com",
        "http://notlocalhost",
        "ftp://localhost",
        "https://example.com/?next=http://localhost",
    ])
    func bareHostRejects(_ url: String) throws {
        #expect(try !matches("localhost", url))
    }

    @Test func schemeRestrictsMatch() throws {
        #expect(try matches("http://localhost", "http://localhost:8080/x"))
        #expect(try !matches("http://localhost", "https://localhost"))
    }

    @Test func subdomainWildcard() throws {
        #expect(try matches("*.example.com", "https://example.com"))
        #expect(try matches("*.example.com", "https://a.b.example.com/path"))
        #expect(try !matches("*.example.com", "https://badexample.com"))
        #expect(try !matches("*.example.com", "https://example.com.evil.io"))
    }

    @Test func pathPrefix() throws {
        #expect(try matches("github.com/myorg/*", "https://github.com/myorg/repo/pulls"))
        #expect(try !matches("github.com/myorg/*", "https://github.com/other/repo"))
        #expect(try matches("github.com/myorg", "https://github.com/myorg"))
    }

    @Test func trailingSlashMatchesBareHost() throws {
        #expect(try matches("localhost/", "http://localhost"))
        #expect(try matches("localhost/*", "http://localhost"))
    }

    @Test func explicitPort() throws {
        #expect(try matches("localhost:3000", "http://localhost:3000/a"))
        #expect(try !matches("localhost:3000", "http://localhost:4000/a"))
        #expect(try !matches("localhost:3000", "http://localhost/a"))
    }

    @Test func wildcardHostAndScheme() throws {
        #expect(try matches("*", "https://anything.test/x"))
        #expect(try matches("http://", "http://anything.test/x"))
        #expect(try !matches("http://", "https://anything.test/x"))
        #expect(try matches("*://localhost", "ws://localhost"))
    }

    @Test func ipv6Host() throws {
        #expect(try matches("[::1]", "http://[::1]:8080/"))
        #expect(try matches("[::1]:8080", "http://[::1]:8080/"))
        #expect(try !matches("[::1]:8080", "http://[::1]:9090/"))
    }

    @Test func regexMetacharactersAreLiteral() throws {
        #expect(try matches("example.com", "https://example.com"))
        #expect(try !matches("example.com", "https://exampleXcom"))
    }
}

struct RegexPatternTests {
    @Test func searchesAnywhereInURL() throws {
        let regex = try RuleMatcher.compile(#"youtube\.com/watch"#, kind: .regex)
        let url = "https://www.youtube.com/watch?v=1"
        #expect(regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil)
    }

    @Test func invalidRegexThrows() {
        #expect(RuleMatcher.validate("([", kind: .regex) != nil)
        #expect(RuleMatcher.validate(#"^https://"#, kind: .regex) == nil)
    }

    @Test(arguments: Rule.Kind.allCases)
    func emptyPatternThrows(_ kind: Rule.Kind) {
        #expect(RuleMatcher.validate("   ", kind: kind) == .empty)
    }
}

struct RuleMatcherTests {
    private let chrome = "com.google.Chrome"
    private let safari = "com.apple.Safari"

    @Test func firstMatchingRuleWins() throws {
        let rules = [
            Rule(name: "Local", pattern: "localhost", kind: .simple, browserIDs: [chrome]),
            Rule(name: "All", pattern: ".*", kind: .regex, browserIDs: [safari]),
        ]
        let matcher = RuleMatcher(rules: rules)
        #expect(matcher.match(try #require(URL(string: "http://localhost:3000")))?.name == "Local")
        #expect(matcher.match(try #require(URL(string: "https://example.com")))?.name == "All")
    }

    @Test func disabledRulesAreSkipped() throws {
        let rules = [Rule(name: "Off", pattern: "localhost", kind: .simple, browserIDs: [chrome], isEnabled: false)]
        #expect(RuleMatcher(rules: rules).match(try #require(URL(string: "http://localhost"))) == nil)
    }

    @Test func invalidRulesAreReportedAndSkipped() throws {
        let bad = Rule(name: "Bad", pattern: "([", kind: .regex, browserIDs: [chrome])
        let good = Rule(name: "Good", pattern: "localhost", kind: .simple, browserIDs: [safari])
        let matcher = RuleMatcher(rules: [bad, good])
        #expect(matcher.invalidRules.keys.contains(bad.id))
        #expect(matcher.match(try #require(URL(string: "http://localhost")))?.name == "Good")
    }

    @Test func noMatchReturnsNil() throws {
        let matcher = RuleMatcher(rules: [Rule(name: "Local", pattern: "localhost", kind: .simple, browserIDs: [chrome])])
        #expect(matcher.match(try #require(URL(string: "https://example.com"))) == nil)
    }
}
