import Foundation

/// Which symbols a flash-card set is made of. Hiragana, katakana and kanji stay separate.
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

/// A named set of symbols to practise with flash cards, e.g. "か row" or "Numbers".
/// Kana are stored by their hiragana (the same set works for the sound in either script).
nonisolated struct FlashSet: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var kind: FlashSetKind
    var items: [String]
}
