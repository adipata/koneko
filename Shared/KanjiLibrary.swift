import Foundation
import Observation

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
    /// Its radical ("family"), e.g. 氵 for 海; used to group kanji from grade 3 on.
    let radical: String?

    var id: String { character }

    /// Readings without dictionary marks: "ひと.つ" → "ひとつ", "-び" → "び".
    nonisolated static func clean(_ reading: String) -> String {
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
        let r: String?
    }

    private(set) var all: [KanjiInfo] = []
    private var byCharacter: [String: KanjiInfo] = [:]

    init(loadData: Bool = true) {
        guard loadData, let url = Bundle.main.url(forResource: "kanji_info", withExtension: "json")
            ?? Bundle.main.url(forResource: "kanji_info", withExtension: "json", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: Raw].self, from: data)
        else { return }
        all = raw.map { character, info in
            KanjiInfo(
                character: character, grade: info.g, strokes: info.s, meanings: info.m,
                on: info.on, kun: info.kun, radical: info.r
            )
        }
        .sorted { ($0.grade, $0.strokes, $0.character) < ($1.grade, $1.strokes, $1.character) }
        byCharacter = Dictionary(uniqueKeysWithValues: all.map { ($0.character, $0) })
    }

    /// A library without data, for decks that don't need kanji (e.g. My words).
    static let empty = KanjiLibrary(loadData: false)

    func info(for character: String) -> KanjiInfo? {
        byCharacter[character]
    }

    func kanji(grade: Int) -> [KanjiInfo] {
        all.filter { $0.grade == grade }
    }

    /// The kanji of a grade in themed groups (grades 1–2) or radical families (grade 3+).
    /// Cached: the view asks again on every redraw.
    func groups(grade: Int) -> [KanjiGroup] {
        if let cached = groupCache[grade] { return cached }
        let groups = KanjiGroups.groups(for: kanji(grade: grade), grade: grade)
        groupCache[grade] = groups
        return groups
    }

    // MARK: Search

    /// Search keys for one kanji, worked out once: converting readings to hiragana and romaji
    /// uses slow text transforms, far too slow to redo for 2,136 kanji on every keystroke.
    private nonisolated struct SearchEntry: Sendable {
        let character: String
        /// Lowercased, without accents.
        let meanings: [String]
        /// Readings in hiragana.
        let kana: [String]
        /// Readings in romaji, without long-vowel marks.
        let romaji: [String]
    }

    @ObservationIgnored private var groupCache: [Int: [KanjiGroup]] = [:]
    @ObservationIgnored private var searchIndex: [SearchEntry]?
    @ObservationIgnored private var indexTask: Task<[SearchEntry], Never>?

    /// Builds the search index in the background (call when the kanji page appears).
    func prepareSearch() async {
        _ = await loadIndex()
    }

    /// Search by meaning (English), reading (kana or romaji) or the kanji itself.
    /// Meanings that start with the query come first.
    func search(_ query: String, limit: Int = 150) async -> [KanjiInfo] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        // Kanji typed directly: show those kanji.
        if JapaneseText.containsKanji(query) {
            return query.compactMap { byCharacter[String($0)] }
        }

        let index = await loadIndex()
        let isKana = JapaneseText.isKana(query)
        let kana = JapaneseText.hiragana(query)
        let folded = Self.fold(query)
        var best: [String] = []
        var other: [String] = []
        for entry in index {
            if isKana {
                if entry.kana.contains(kana) { best.append(entry.character) }
                else if entry.kana.contains(where: { $0.hasPrefix(kana) }) { other.append(entry.character) }
                continue
            }
            if entry.meanings.contains(where: { $0 == folded || $0.hasPrefix(folded + " ") }) {
                best.append(entry.character)
            } else if entry.meanings.contains(where: { $0.contains(folded) }) || entry.romaji.contains(folded) {
                other.append(entry.character)
            }
        }
        return (best + other).prefix(limit).compactMap { byCharacter[$0] }
    }

    private func loadIndex() async -> [SearchEntry] {
        if let searchIndex { return searchIndex }
        let task: Task<[SearchEntry], Never>
        if let indexTask {
            task = indexTask
        } else {
            let sources = all.map { (character: $0.character, meanings: $0.meanings, readings: $0.kun + $0.on) }
            task = Task.detached(priority: .userInitiated) {
                sources.map { source in
                    let kana = source.readings.map { JapaneseText.hiragana(KanjiInfo.clean($0)) }
                    return SearchEntry(
                        character: source.character,
                        meanings: source.meanings.map(Self.fold),
                        kana: kana,
                        romaji: kana.map { Self.fold(JapaneseText.romaji($0)) }
                    )
                }
            }
            indexTask = task
        }
        let index = await task.value
        searchIndex = index
        return index
    }

    private nonisolated static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
