import Foundation

enum PatternError: LocalizedError, Equatable {
    case empty
    case invalidRegex(String)
    case invalidPattern

    var errorDescription: String? {
        switch self {
        case .empty: "The pattern is empty."
        case .invalidRegex(let reason): "Invalid regular expression: \(reason)"
        case .invalidPattern: "The pattern could not be understood."
        }
    }
}

/// Finds the first enabled rule matching a URL. Rules are compiled once at init.
struct RuleMatcher {
    private let compiled: [(rule: Rule, regex: NSRegularExpression)]
    /// Enabled rules whose pattern failed to compile; these never match.
    let invalidRules: [UUID: PatternError]

    init(rules: [Rule]) {
        var compiled: [(Rule, NSRegularExpression)] = []
        var invalid: [UUID: PatternError] = [:]
        for rule in rules where rule.isEnabled {
            do {
                compiled.append((rule, try Self.compile(rule.pattern, kind: rule.kind)))
            } catch {
                invalid[rule.id] = error
            }
        }
        self.compiled = compiled
        self.invalidRules = invalid
    }

    func match(_ url: URL) -> Rule? {
        let string = url.absoluteString
        let range = NSRange(string.startIndex..., in: string)
        return compiled.first { $0.regex.firstMatch(in: string, range: range) != nil }?.rule
    }

    static func validate(_ pattern: String, kind: Rule.Kind) -> PatternError? {
        do {
            _ = try compile(pattern, kind: kind)
            return nil
        } catch {
            return error
        }
    }

    static func compile(_ pattern: String, kind: Rule.Kind) throws(PatternError) -> NSRegularExpression {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .empty }

        switch kind {
        case .regex:
            do {
                return try NSRegularExpression(pattern: trimmed)
            } catch {
                throw .invalidRegex(error.localizedDescription)
            }
        case .simple:
            do {
                return try NSRegularExpression(pattern: SimplePattern.regexSource(for: trimmed), options: .caseInsensitive)
            } catch {
                throw .invalidPattern
            }
        }
    }
}

/// Translates a simple pattern into an anchored regex over the absolute URL string.
///
/// `[scheme://]host[:port][/path]`
/// - No scheme matches `http` and `https`.
/// - `*.example.com` matches `example.com` and all its subdomains; `*` elsewhere is a wildcard.
/// - No port matches any port. No path matches the whole host; a path matches as a prefix.
/// - Matching is case-insensitive.
enum SimplePattern {
    private static let hostChars = "[^/?#:@]"

    static func regexSource(for pattern: String) -> String {
        var rest = Substring(pattern)

        let scheme: String
        if let separator = rest.range(of: "://") {
            scheme = glob(rest[..<separator.lowerBound], wildcard: "[a-z0-9+.-]*")
            rest = rest[separator.upperBound...]
        } else {
            scheme = "https?"
        }

        let authorityEnd = rest.firstIndex { "/?#".contains($0) } ?? rest.endIndex
        let (host, port) = splitHostAndPort(rest[..<authorityEnd])
        var tail = rest[authorityEnd...]
        if tail == "/" || tail == "/*" {
            tail = ""
        }

        var source = "^\(scheme)://(?:[^/?#@]*@)?\(hostSource(host))"
        if let port {
            source += ":" + glob(port, wildcard: "[0-9]*")
        } else {
            source += "(?::[0-9]+)?"
        }
        if tail.isEmpty {
            source += "(?:[/?#].*)?$"
        } else {
            source += glob(tail, wildcard: ".*")
        }
        return source
    }

    private static func hostSource(_ host: Substring) -> String {
        if host.isEmpty || host == "*" {
            return "\(hostChars)*"
        }
        if host.hasPrefix("*.") {
            return "(?:\(hostChars)+\\.)?" + glob(host.dropFirst(2), wildcard: "\(hostChars)*")
        }
        return glob(host, wildcard: "\(hostChars)*")
    }

    private static func splitHostAndPort(_ authority: Substring) -> (host: Substring, port: Substring?) {
        // IPv6 literal, e.g. [::1]:8080
        if authority.hasPrefix("["), let close = authority.firstIndex(of: "]") {
            let host = authority[...close]
            let after = authority[authority.index(after: close)...]
            return (host, after.hasPrefix(":") ? after.dropFirst() : nil)
        }
        if let colon = authority.lastIndex(of: ":") {
            return (authority[..<colon], authority[authority.index(after: colon)...])
        }
        return (authority, nil)
    }

    private static func glob(_ text: Substring, wildcard: String) -> String {
        text.split(separator: "*", omittingEmptySubsequences: false)
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: wildcard)
    }
}
