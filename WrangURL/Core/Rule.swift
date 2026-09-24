import Foundation

struct Rule: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, CaseIterable, Sendable {
        /// Host/prefix pattern with `*` wildcards, e.g. `localhost`, `*.example.com`, `github.com/myorg/*`.
        case simple
        /// Regular expression searched for anywhere in the absolute URL string.
        case regex
    }

    var id = UUID()
    var name: String
    var pattern: String
    var kind: Kind
    /// Bundle identifiers, in the order they appear in the picker.
    var browserIDs: [String]
    var isEnabled = true
}

extension Rule {
    // Tolerate missing keys so older or hand-edited config files still load.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        pattern = try container.decode(String.self, forKey: .pattern)
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .simple
        browserIDs = try container.decodeIfPresent([String].self, forKey: .browserIDs) ?? []
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}
