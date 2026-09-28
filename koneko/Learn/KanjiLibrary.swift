import Foundation

/// A kanji with its meanings and readings (from Resources/kanji_info.json, works offline).
struct KanjiInfo: Identifiable, Hashable {
    let character: String
    /// 1–6 = elementary school grade, 7 = secondary school.
    let grade: Int
    let strokes: Int
    let meanings: [String]
    /// "Chinese" readings (on'yomi).
    let on: [String]
    /// "Japanese" readings (kun'yomi), e.g. "ひと.つ" (the part after the dot is written in kana).
    let kun: [String]

    var id: String { character }

    /// Readings without dictionary marks: "ひと.つ" → "ひとつ", "-び" → "び".
    static func clean(_ reading: String) -> String {
        reading.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: "-", with: "")
    }

    /// The reading to say aloud: the first Japanese reading, or else the first Chinese one.
    var mainReading: String {
        Self.clean(kun.first ?? on.first ?? "")
    }

    var shortMeaning: String { meanings.first ?? "" }
}

/// All 2,136 common kanji, by school grade, with search.
@Observable
final class KanjiLibrary {
    private nonisolated struct Raw: Decodable {
        let g: Int
        let s: Int
        let m: [String]
        let on: [String]
        let kun: [String]
    }

    private(set) var all: [KanjiInfo] = []
    private var byCharacter: [String: KanjiInfo] = [:]

    init() {
        guard let url = Bundle.main.url(forResource: "kanji_info", withExtension: "json")
            ?? Bundle.main.url(forResource: "kanji_info", withExtension: "json", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: Raw].self, from: data)
        else { return }
        all = raw.map { character, info in
            KanjiInfo(character: character, grade: info.g, strokes: info.s, meanings: info.m, on: info.on, kun: info.kun)
        }
        .sorted { ($0.grade, $0.strokes, $0.character) < ($1.grade, $1.strokes, $1.character) }
        byCharacter = Dictionary(uniqueKeysWithValues: all.map { ($0.character, $0) })
    }

    func info(for character: String) -> KanjiInfo? {
        byCharacter[character]
    }

    func kanji(grade: Int) -> [KanjiInfo] {
        all.filter { $0.grade == grade }
    }

    /// Search by meaning (English), reading (kana or romaji) or the kanji itself.
    /// Meanings that start with the query come first.
    func search(_ query: String, limit: Int = 150) -> [KanjiInfo] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        // Kanji typed directly: show those kanji.
        if JapaneseText.containsKanji(query) {
            return query.compactMap { byCharacter[String($0)] }
        }

        let isKana = JapaneseText.isKana(query)
        let kana = JapaneseText.hiragana(query)
        let lower = query.lowercased()
        var best: [KanjiInfo] = []
        var other: [KanjiInfo] = []
        for info in all {
            let readings = (info.kun + info.on).map { JapaneseText.hiragana(KanjiInfo.clean($0)) }
            if isKana {
                if readings.contains(kana) { best.append(info) }
                else if readings.contains(where: { $0.hasPrefix(kana) }) { other.append(info) }
                continue
            }
            if info.meanings.contains(where: { $0.lowercased() == lower || $0.lowercased().hasPrefix(lower + " ") }) {
                best.append(info)
            } else if info.meanings.contains(where: { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil })
                        || readings.contains(where: { JapaneseText.romaji($0).folding(options: .diacriticInsensitive, locale: nil) == lower }) {
                other.append(info)
            }
        }
        return Array((best + other).prefix(limit))
    }
}
