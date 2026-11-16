import Foundation

/// One part a kanji is built from, e.g. 禾 "grain" in 秋.
struct KanjiPart: Hashable, Identifiable {
    let character: String
    /// Meanings in English, e.g. ["Tree", "Wood"].
    let meanings: [String]
    /// The radical's Japanese name, e.g. "さんずい" for 氵 (only for radicals).
    let name: String?
    /// The full kanji a squeezed radical comes from, e.g. 水 for 氵.
    let source: String?
    /// "Japanese" (kun) and "Chinese" (on) readings, already without dictionary marks.
    let kun: [String]
    let on: [String]

    var id: String { character }
    var meaning: String { meanings.joined(separator: ", ") }
    /// Japanese readings first, then Chinese ones, each once.
    var readings: [String] {
        var seen = Set<String>()
        return (kun + on).filter { seen.insert($0).inserted }
    }
}

/// The parts of each jōyō kanji (Resources/kanji_parts.json, built from KanjiVG and KANJIDIC2
/// by Tools/build_kanji_parts.py; works offline).
final class KanjiParts {
    static let shared = KanjiParts()

    private nonisolated struct Raw: Decodable {
        nonisolated struct Part: Decodable {
            let m: [String]
            let n: String?
            let f: String?
            let k: [String]?
            let o: [String]?
        }
        let kanji: [String: [String]]
        let parts: [String: Part]
    }

    private var kanji: [String: [String]] = [:]
    private var parts: [String: KanjiPart] = [:]

    private init() {
        guard let url = Bundle.main.url(forResource: "kanji_parts", withExtension: "json")
            ?? Bundle.main.url(forResource: "kanji_parts", withExtension: "json", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(Raw.self, from: data)
        else { return }
        kanji = raw.kanji
        parts = Dictionary(uniqueKeysWithValues: raw.parts.map { character, part in
            (character, KanjiPart(
                character: character, meanings: part.m, name: part.n, source: part.f,
                kun: part.k ?? [], on: part.o ?? []
            ))
        })
    }

    /// The parts of a kanji, in writing order (e.g. 秋 → 禾, 火). Empty for simple kanji like 木.
    func parts(of character: String) -> [KanjiPart] {
        (kanji[character] ?? []).compactMap { parts[$0] }
    }
}
