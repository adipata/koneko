import Foundation

/// The language the child typed or spoke the word in.
nonisolated enum InputLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .japanese: "Japanese"
        }
    }
}

/// One possible Japanese word for what the child asked for.
nonisolated struct WordCandidate: Codable, Hashable, Identifiable, Sendable {
    /// A piece of the word with its reading, e.g. 学 → がく. Used for furigana.
    nonisolated struct Part: Codable, Hashable, Sendable {
        var text: String
        var reading: String
    }

    /// How the word is normally written (kanji and/or kana).
    var japanese: String
    /// Full reading in hiragana.
    var reading: String
    var romaji: String
    /// Short, child-friendly English explanation.
    var meaning: String
    var emoji: String
    var isLoanword: Bool
    var parts: [Part]

    var id: String { japanese + "|" + reading + "|" + meaning }

    /// A word typed directly in Japanese, shown without asking the LLM.
    static func direct(_ text: String) -> WordCandidate {
        let reading = JapaneseText.containsKanji(text) ? "" : JapaneseText.hiragana(text)
        return WordCandidate(
            japanese: text, reading: reading, romaji: "", meaning: "", emoji: "",
            isLoanword: false, parts: [Part(text: text, reading: reading)]
        )
    }

    /// Checks and cleans up a candidate returned by the LLM. Returns nil if it's unusable.
    func validated() -> WordCandidate? {
        var word = self
        word.japanese = japanese.trimmingCharacters(in: .whitespacesAndNewlines)
        word.reading = JapaneseText.hiragana(reading.trimmingCharacters(in: .whitespacesAndNewlines))
        word.romaji = romaji.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        word.meaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        word.emoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !word.japanese.isEmpty,
              JapaneseText.isJapanese(word.japanese),
              JapaneseText.isKana(word.reading)
        else { return nil }

        word.parts = parts.map {
            Part(text: $0.text, reading: JapaneseText.hiragana($0.reading.trimmingCharacters(in: .whitespaces)))
        }
        if word.parts.map(\.text).joined() != word.japanese {
            word.parts = [Part(text: word.japanese, reading: word.reading)]
        }
        return word
    }
}

/// Small helpers for classifying and converting Japanese text.
nonisolated enum JapaneseText {
    static func isHiragana(_ scalar: Unicode.Scalar) -> Bool { (0x3041...0x309F).contains(scalar.value) }
    static func isKatakana(_ scalar: Unicode.Scalar) -> Bool { (0x30A0...0x30FF).contains(scalar.value) }
    static func isKanji(_ scalar: Unicode.Scalar) -> Bool {
        (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value) || scalar == "々"
    }
    static func isJapanesePunctuationOrSpace(_ scalar: Unicode.Scalar) -> Bool {
        (0x3000...0x303F).contains(scalar.value) || scalar == " " || (0xFF01...0xFF0F).contains(scalar.value)
    }

    /// Only hiragana/katakana (plus spaces and Japanese punctuation).
    static func isKana(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy {
            isHiragana($0) || isKatakana($0) || isJapanesePunctuationOrSpace($0)
        }
    }

    /// Only Japanese script: kana, kanji, Japanese punctuation, spaces.
    static func isJapanese(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy {
            isHiragana($0) || isKatakana($0) || isKanji($0) || isJapanesePunctuationOrSpace($0)
        }
    }

    static func containsKanji(_ text: String) -> Bool {
        text.unicodeScalars.contains(where: isKanji)
    }

    /// Converts katakana to hiragana (ー and other characters are kept).
    static func hiragana(_ text: String) -> String {
        text.applyingTransform(.hiraganaToKatakana, reverse: true) ?? text
    }

    static func katakana(_ text: String) -> String {
        text.applyingTransform(.hiraganaToKatakana, reverse: false) ?? text
    }
}

extension WordCandidate {
    /// Tolerant decoding: some models skip optional-looking fields even with a strict schema.
    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        japanese = try container.decode(String.self, forKey: .japanese)
        reading = try container.decodeIfPresent(String.self, forKey: .reading) ?? ""
        romaji = try container.decodeIfPresent(String.self, forKey: .romaji) ?? ""
        meaning = try container.decodeIfPresent(String.self, forKey: .meaning) ?? ""
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? ""
        isLoanword = try container.decodeIfPresent(Bool.self, forKey: .isLoanword) ?? false
        parts = try container.decodeIfPresent([Part].self, forKey: .parts) ?? []
    }
}

extension WordCandidate {
    /// Romaji for each character of `japanese` (same order and count).
    /// Kana are grouped into syllables (きょ → "kyo" on き, nothing on ょ; っ shows the doubled
    /// consonant); a kanji shows the reading of its part in this word.
    nonisolated func romajiPerCharacter() -> [String] {
        let characters = Array(japanese)
        var result: [String] = []
        for part in parts {
            let partCharacters = Array(part.text)
            if JapaneseText.containsKanji(part.text) {
                let partRomaji = part.reading.isEmpty ? "" : JapaneseText.romaji(part.reading)
                result += partCharacters.map {
                    JapaneseText.containsKanji(String($0)) ? partRomaji : JapaneseText.romaji(String($0))
                }
            } else {
                result += JapaneseText.romajiPerKana(partCharacters)
            }
        }
        // Parts should always rebuild the word; fall back to per-kana romaji if they don't.
        return result.count == characters.count ? result : JapaneseText.romajiPerKana(characters)
    }
}

nonisolated extension JapaneseText {
    private static let smallYouon: Set<Character> = ["ゃ", "ゅ", "ょ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ", "ャ", "ュ", "ョ", "ァ", "ィ", "ゥ", "ェ", "ォ"]
    private static let sokuon: Set<Character> = ["っ", "ッ"]

    /// Hepburn-style romaji for kana, e.g. がっこう → gakkō.
    static func romaji(_ kana: String) -> String {
        let latin = hiragana(kana).applyingTransform(.toLatin, reverse: false) ?? kana
        return latin.lowercased()
    }

    static func romajiPerKana(_ characters: [Character]) -> [String] {
        var result: [String] = []
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if index + 1 < characters.count, smallYouon.contains(characters[index + 1]) {
                result += [romaji(String(character) + String(characters[index + 1])), ""]
                index += 2
                continue
            }
            if sokuon.contains(character) {
                let next = index + 1 < characters.count ? romaji(String(characters[index + 1])) : ""
                result.append(next.first.map { $0.isLetter ? String($0) : "" } ?? "")
            } else if character == "ー" {
                result.append("(long)")
            } else if isKana(String(character)) {
                result.append(romaji(String(character)))
            } else {
                result.append("")
            }
            index += 1
        }
        return result
    }
}
