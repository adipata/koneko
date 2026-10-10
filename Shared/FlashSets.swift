import Foundation

/// The kind of a symbol in a flash-card set: hiragana, katakana or kanji.
nonisolated enum FlashSetKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case hiragana
    case katakana
    case kanji

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hiragana: "Hiragana"
        case .katakana: "Katakana"
        case .kanji: "Kanji"
        }
    }
}

/// One symbol in a set. Kana are stored by their hiragana (the chart cell id), with `kind`
/// saying which script to show; kanji by their character.
nonisolated struct FlashSymbol: Codable, Hashable, Sendable {
    var kind: FlashSetKind
    var value: String
}

/// A named set of symbols to practise with flash cards, e.g. "か row" or "Numbers".
/// A set can mix hiragana, katakana and kanji.
nonisolated struct FlashSet: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var symbols: [FlashSymbol]

    init(id: UUID = UUID(), name: String, symbols: [FlashSymbol]) {
        self.id = id
        self.name = name
        self.symbols = symbols
    }

    /// The kinds in this set, in hiragana, katakana, kanji order.
    var kinds: [FlashSetKind] {
        let present = Set(symbols.map(\.kind))
        return FlashSetKind.allCases.filter(present.contains)
    }

    /// e.g. "5 hiragana · 3 kanji".
    var summary: String {
        kinds.map { kind in
            "\(symbols.filter { $0.kind == kind }.count) \(kind.title.lowercased())"
        }
        .joined(separator: " · ")
    }

    // Sets saved before mixing was possible have one `kind` and plain `items`.
    private enum CodingKeys: String, CodingKey {
        case id, name, symbols, kind, items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        if let symbols = try container.decodeIfPresent([FlashSymbol].self, forKey: .symbols) {
            self.symbols = symbols
        } else {
            let kind = try container.decode(FlashSetKind.self, forKey: .kind)
            let items = try container.decode([String].self, forKey: .items)
            symbols = items.map { FlashSymbol(kind: kind, value: $0) }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(symbols, forKey: .symbols)
    }
}
