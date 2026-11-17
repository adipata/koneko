import Foundation

/// Asks the AI to read and explain one part of a book or manga, with the earlier parts of the
/// same reading as context. Only the earlier texts (and hidden scene notes) are sent, never the
/// earlier explanations.
enum ReadingExplainer {
    /// What she gives the AI.
    enum Input {
        /// Text selected in the photo (read on the device).
        case text(String)
        /// A cropped part of the photo, as JPEG.
        case picture(Data)
    }

    /// The new entry, ready to add to the reading. Throws `ReadingExplainerError.nothingToRead`
    /// when the picture has no Japanese text.
    static func explain(_ input: Input, in reading: Reading, model: AIModel) async throws -> ReadingEntry {
        let client = try model.client()
        let task: String
        let jpeg: Data?
        switch input {
        case .text(let text):
            task = "Explain this text from it:\n\(text)"
            jpeg = nil
        case .picture(let picture):
            task = reading.kind == .manga
                ? "Read and explain the text in this picture from it (usually one manga panel)."
                : "Read and explain the text in this picture from it."
            jpeg = picture
        }
        let answer = try await ask(client, user: userMessage(for: reading, earlier: reading.entries, task: task), imageJPEG: jpeg)

        var text = answer.text
        if case .text(let selected) = input, text.isEmpty {
            text = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !text.isEmpty else { throw ReadingExplainerError.nothingToRead }
        guard !answer.explanation.isEmpty else { throw TranslationError.badResponse }

        let source: ReadingSource
        if case .picture = input { source = .picture } else { source = .text }
        let scene = source == .picture && reading.kind == .manga ? answer.scene : ""
        return ReadingEntry(text: text, source: source, scene: scene, explanation: answer.explanation)
    }

    /// A new explanation for a saved part (its text; the picture isn't kept), with the parts
    /// before it as context. Used when an explanation is missing or to get a better one.
    static func explainAgain(_ entry: ReadingEntry, in reading: Reading, model: AIModel) async throws -> ReadingExplanation {
        let client = try model.client()
        let earlier = Array(reading.entries.prefix { $0.id != entry.id })
        var task = "Explain this text from it:\n\(entry.text)"
        if !entry.scene.isEmpty {
            task = "This text is from a manga panel that shows: \(entry.scene)\n" + task
        }
        let answer = try await ask(client, user: userMessage(for: reading, earlier: earlier, task: task), imageJPEG: nil)
        guard !answer.explanation.isEmpty else { throw TranslationError.badResponse }
        return answer.explanation
    }

    /// Asks the AI, and asks once more if the answer came back without an explanation (some
    /// models now and then return empty fields). A picture with no text at all is returned as is.
    private static func ask(_ client: any AIClient, user: String, imageJPEG: Data?) async throws -> Answer {
        var answer = try await request(client, user: user, imageJPEG: imageJPEG)
        if answer.explanation.isEmpty, !answer.text.isEmpty {
            answer = try await request(client, user: user, imageJPEG: imageJPEG)
        }
        return answer
    }

    private static func request(_ client: any AIClient, user: String, imageJPEG: Data?) async throws -> Answer {
        let raw: Answer = try await client.requestJSON(
            system: systemPrompt,
            user: user,
            imageJPEG: imageJPEG,
            schemaName: "reading_explanation",
            schema: schema,
            maxTokens: 5000
        )
        return raw.repaired()
    }

    // MARK: Context

    /// How many earlier parts are sent, and how long each one may be.
    private static let contextEntries = 15
    private static let contextCharacters = 300

    /// `earlier`: the parts read before this one, oldest first (only the last few are sent).
    private static func userMessage(for reading: Reading, earlier entries: [ReadingEntry], task: String) -> String {
        var message = "She is reading a \(reading.kind == .manga ? "manga" : "book") called “\(reading.title)”.\n"
        let earlier = entries.suffix(contextEntries)
        if !earlier.isEmpty {
            message += "\nWhat she read just before, oldest first (context only, don't explain it again):\n"
            for (number, entry) in earlier.enumerated() {
                var line = "\(number + 1). "
                if !entry.scene.isEmpty { line += "[Panel: \(entry.scene.prefix(contextCharacters))] " }
                line += String(entry.text.replacingOccurrences(of: "\n", with: " ").prefix(contextCharacters))
                message += line + "\n"
            }
        }
        message += "\n" + task
        return message
    }

    // MARK: Prompt

    private static let systemPrompt = """
    You are a Japanese tutor for an English-speaking learner reading a real Japanese book or manga.
    Treat her as an adult learner: be clear, precise and concise, use standard grammar terms (with a
    short gloss for less common ones), and be accurate above all. She shows you one short part at a
    time: either the text itself, or a picture (a crop of a page; for a manga, usually one panel).

    Return:
    - "text": the Japanese text exactly as written. From a picture: read all the words in reading
      order (manga: speech bubbles right to left, top to bottom; vertical lines top to bottom), one
      bubble or sentence per line. Leave out small furigana printed beside kanji. Include sound
      effects only if they are clearly part of the text. If you were given the text, it was read
      from a photo by on-device text recognition, which sometimes mistakes a character for a
      similar-looking one (e.g. 電聞 for 電話, 稼 for 嫁): return it with such misreadings corrected
      when the meaning and context make the right character clear, and with stray spaces or line
      breaks inside a sentence removed; otherwise unchanged. If there is no Japanese text, return
      an empty string.
    - "scene": only for a manga picture: one or two short sentences about what the panel shows
      (who is there, what they do, their feelings, who is speaking). Otherwise an empty string.
    - "translation": a natural English translation (not word for word).
    - "kana": the whole text written in kana only (hiragana; words normally written in katakana
      stay in katakana), with a space between words.
    - "explanation": one paragraph (about 4 to 7 sentences) for someone who knows English and is
      learning Japanese: how the sentence is built (word order, what each particle does, verb forms
      such as polite or plain, past, negative, te-form), and words that have other meanings or a
      special nuance here (casual speech, sentence-ending particles, onomatopoeia, who is talking to
      whom). Use what she read before to fill in a subject or meaning the text leaves out, and say
      when you do. When you quote Japanese, add its kana reading in brackets if it has kanji. If part
      of the text is unclear or cut off, say so. If you corrected any misread characters in "text",
      start with one short sentence naming each change (e.g. "Corrected: 電聞 → 電話 (でんわ).").
    - "words": the words and grammar pieces in order (at most 12; skip repeats): "japanese" as
      written, "reading" in hiragana, "meaning" in short English, "note" with its role in a few words
      (e.g. "topic particle", "past form of 食べる").
    - "kanji": every different kanji in the text, even common ones: "kanji", "reading" (the reading used here, in
      hiragana), "meaning" in short English, "note" in a few words on how it is used here (e.g. the
      word it is part of). An empty list if there are no kanji.
    """

    private static var schema: [String: Any] {
        let piece: (String) -> [String: Any] = { key in
            [
                "type": "object",
                "additionalProperties": false,
                "required": [key, "reading", "meaning", "note"],
                "properties": [
                    key: ["type": "string"],
                    "reading": ["type": "string"],
                    "meaning": ["type": "string"],
                    "note": ["type": "string"],
                ],
            ]
        }
        return [
            "type": "object",
            "additionalProperties": false,
            "required": ["text", "scene", "translation", "kana", "explanation", "words", "kanji"],
            "properties": [
                "text": ["type": "string"],
                "scene": ["type": "string"],
                "translation": ["type": "string"],
                "kana": ["type": "string"],
                "explanation": ["type": "string"],
                "words": ["type": "array", "items": piece("japanese")],
                "kanji": ["type": "array", "items": piece("kanji")],
            ],
        ]
    }
}

enum ReadingExplainerError: Error {
    case nothingToRead
}

/// The AI's answer as it comes, tidied by `repaired()`.
private nonisolated struct Answer: Decodable, Sendable {
    var text: String
    var scene: String
    var translation: String
    var kana: String
    var explanationText: String
    var words: [ReadingExplanation.Word]
    var kanji: [ReadingExplanation.Kanji]

    private enum CodingKeys: String, CodingKey {
        case text, scene, translation, kana, words, kanji
        case explanationText = "explanation"
    }

    /// Tolerant: a field the model skipped is empty instead of failing the whole answer.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
        scene = (try? container.decodeIfPresent(String.self, forKey: .scene)) ?? ""
        translation = (try? container.decodeIfPresent(String.self, forKey: .translation)) ?? ""
        kana = (try? container.decodeIfPresent(String.self, forKey: .kana)) ?? ""
        explanationText = (try? container.decodeIfPresent(String.self, forKey: .explanationText)) ?? ""
        words = (try? container.decodeIfPresent([ReadingExplanation.Word].self, forKey: .words)) ?? []
        kanji = (try? container.decodeIfPresent([ReadingExplanation.Kanji].self, forKey: .kanji)) ?? []
    }

    /// The explanation to save (trimmed; empty rows dropped).
    var explanation: ReadingExplanation {
        ReadingExplanation(
            translation: Self.clean(translation),
            kana: Self.clean(kana),
            explanation: Self.clean(explanationText),
            words: words
                .map { ReadingExplanation.Word(japanese: Self.clean($0.japanese), reading: Self.clean($0.reading), meaning: Self.clean($0.meaning), note: Self.clean($0.note)) }
                .filter { !$0.japanese.isEmpty },
            kanji: kanji
                .map { ReadingExplanation.Kanji(kanji: Self.clean($0.kanji), reading: Self.clean($0.reading), meaning: Self.clean($0.meaning), note: Self.clean($0.note)) }
                .filter { !$0.kanji.isEmpty }
        )
    }

    /// Some models close a text field too late, so the rest of the answer
    /// (`", "translation": "…", …}`) ends up inside it and the other fields are empty. This cuts
    /// the leaked JSON out and recovers the fields it held (as `KanjiExplanation.repaired()` does).
    func repaired() -> Answer {
        var result = self
        var leaked: [String: Any] = [:]
        result.text = Self.cutLeakedJSON(from: text, into: &leaked)
        result.scene = Self.cutLeakedJSON(from: scene, into: &leaked)
        result.translation = Self.cutLeakedJSON(from: translation, into: &leaked)
        result.kana = Self.cutLeakedJSON(from: kana, into: &leaked)
        result.explanationText = Self.cutLeakedJSON(from: explanationText, into: &leaked)

        if result.scene.isEmpty, let value = leaked["scene"] as? String { result.scene = value }
        if result.translation.isEmpty, let value = leaked["translation"] as? String { result.translation = value }
        if result.kana.isEmpty, let value = leaked["kana"] as? String { result.kana = value }
        if result.explanationText.isEmpty, let value = leaked["explanation"] as? String { result.explanationText = value }
        if result.words.isEmpty, let items = leaked["words"] as? [[String: Any]] {
            result.words = items.compactMap { item in
                guard let japanese = item["japanese"] as? String else { return nil }
                return ReadingExplanation.Word(
                    japanese: japanese, reading: item["reading"] as? String ?? "",
                    meaning: item["meaning"] as? String ?? "", note: item["note"] as? String ?? ""
                )
            }
        }
        if result.kanji.isEmpty, let items = leaked["kanji"] as? [[String: Any]] {
            result.kanji = items.compactMap { item in
                guard let kanji = item["kanji"] as? String else { return nil }
                return ReadingExplanation.Kanji(
                    kanji: kanji, reading: item["reading"] as? String ?? "",
                    meaning: item["meaning"] as? String ?? "", note: item["note"] as? String ?? ""
                )
            }
        }
        result.text = Self.clean(result.text)
        result.scene = Self.clean(result.scene)
        return result
    }

    /// Returns the text before a leaked `", "field":` marker, and parses the JSON after it into `leaked`.
    private static func cutLeakedJSON(from text: String, into leaked: inout [String: Any]) -> String {
        let plain = text.replacingOccurrences(of: "\\\"", with: "\"")
        let marker = #"\s*,\s*"(text|scene|translation|kana|explanation|words|kanji)"\s*:"#
        guard let found = plain.range(of: marker, options: .regularExpression),
              let keyStart = plain[found].firstIndex(of: "\"")
        else { return text }

        // The leaked part may or may not keep its closing brace; try a few endings.
        let tail = String(plain[keyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let body = tail.trimmingCharacters(in: CharacterSet(charactersIn: "}\" \n\t"))
        for candidate in ["{" + tail, "{" + tail + "}", "{" + body + "}", "{" + body + "\"}", "{" + body + "]}"] {
            if let object = try? JSONSerialization.jsonObject(with: Data(candidate.utf8)) as? [String: Any] {
                leaked.merge(object) { current, _ in current }
                break
            }
        }
        return String(plain[..<found.lowerBound]).trimmingCharacters(in: CharacterSet(charactersIn: "\"“”, \n\t"))
    }

    private static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
