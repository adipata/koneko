import CoreText
import SwiftUI

/// How a word is written on screen.
nonisolated enum WritingStyle: String, CaseIterable, Identifiable, Sendable {
    /// As adults write it.
    case natural
    /// Only kanji up to her school level; other kanji become hiragana (like children's books).
    case schoolLevel
    case hiragana
    case katakana

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .natural: "Like adults write"
        case .schoolLevel: "Only kanji she has learned"
        case .hiragana: "Only hiragana"
        case .katakana: "Only katakana"
        }
    }

    /// Kanji levels: 0 = none yet, 1–6 = elementary grades, 7 = all jōyō kanji.
    static func levelName(_ level: Int) -> String {
        switch level {
        case 0: "No kanji yet"
        case 1...6: "Up to grade \(level) (\(KanjiGrades.cumulativeCount(upTo: level)) kanji)"
        default: "All common kanji (2,136)"
        }
    }

    /// Rewrites `word` in this style. The reading (used for speech) never changes.
    func apply(to word: WordCandidate, kanjiLevel: Int) -> WordCandidate {
        guard !word.reading.isEmpty else { return word } // typed kanji with unknown reading
        var result = word
        switch self {
        case .natural:
            return word
        case .hiragana:
            let text = JapaneseText.hiragana(word.reading)
            result.japanese = text
            result.parts = [.init(text: text, reading: text)]
        case .katakana:
            let text = JapaneseText.katakana(word.reading)
            result.japanese = text
            result.parts = [.init(text: text, reading: text)]
        case .schoolLevel:
            result.parts = word.parts.map { part in
                let kanji = part.text.filter { JapaneseText.containsKanji(String($0)) }
                let known = kanji.allSatisfy { (KanjiGrades.grade(of: $0) ?? 99) <= kanjiLevel }
                return known || part.reading.isEmpty ? part : .init(text: part.reading, reading: part.reading)
            }
            result.japanese = result.parts.map(\.text).joined()
        }
        return result
    }
}

/// The school grade in which each kanji is taught (from Resources/kanji_grades.json).
nonisolated enum KanjiGrades {
    private static let grades: [String: Int] = {
        guard let url = Bundle.main.url(forResource: "kanji_grades", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let grades = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return grades
    }()

    /// 1–6 for elementary grades, 7 for other jōyō kanji, nil for rarer kanji.
    static func grade(of kanji: Character) -> Int? {
        grades[String(kanji)]
    }

    static func cumulativeCount(upTo level: Int) -> Int {
        grades.values.filter { $0 <= level }.count
    }
}

/// The handwriting-style font (Klee One), close to how children learn to write.
enum HandwritingFont {
    static let name = "KleeOne-SemiBold"

    /// Registers the bundled font; call once at launch.
    static func register() {
        guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

extension Font {
    static func handwriting(size: CGFloat) -> Font {
        .custom(HandwritingFont.name, size: size)
    }
}
