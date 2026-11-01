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

    private nonisolated struct Answer: Decodable, Sendable {
        let text: String
        let scene: String
        let translation: String
        let kana: String
        let explanation: String
        let words: [ReadingExplanation.Word]
        let kanji: [ReadingExplanation.Kanji]
    }

    /// The new entry, ready to add to the reading. Throws `ReadingExplainerError.nothingToRead`
    /// when the picture has no Japanese text.
    static func explain(_ input: Input, in reading: Reading, model: AIModel) async throws -> ReadingEntry {
        let client = try model.client()
        let answer: Answer
        switch input {
        case .text(let text):
            answer = try await client.requestJSON(
                system: systemPrompt,
                user: userMessage(for: reading, task: "Explain this text from it:\n\(text)"),
                imageJPEG: nil,
                schemaName: "reading_explanation",
                schema: schema,
                maxTokens: 5000
            )
        case .picture(let jpeg):
            let what = reading.kind == .manga
                ? "Read and explain the text in this picture from it (usually one manga panel)."
                : "Read and explain the text in this picture from it."
            answer = try await client.requestJSON(
                system: systemPrompt,
                user: userMessage(for: reading, task: what),
                imageJPEG: jpeg,
                schemaName: "reading_explanation",
                schema: schema,
                maxTokens: 5000
            )
        }

        var text = answer.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if case .text(let selected) = input, text.isEmpty {
            text = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !text.isEmpty else { throw ReadingExplainerError.nothingToRead }

        let source: ReadingSource
        if case .picture = input { source = .picture } else { source = .text }
        let scene = source == .picture && reading.kind == .manga ? clean(answer.scene) : ""
        return ReadingEntry(
            text: text,
            source: source,
            scene: scene,
            explanation: ReadingExplanation(
                translation: clean(answer.translation),
                kana: clean(answer.kana),
                explanation: clean(answer.explanation),
                words: answer.words
                    .map { ReadingExplanation.Word(japanese: clean($0.japanese), reading: clean($0.reading), meaning: clean($0.meaning), note: clean($0.note)) }
                    .filter { !$0.japanese.isEmpty },
                kanji: answer.kanji
                    .map { ReadingExplanation.Kanji(kanji: clean($0.kanji), reading: clean($0.reading), meaning: clean($0.meaning), note: clean($0.note)) }
                    .filter { !$0.kanji.isEmpty }
            )
        )
    }

    private nonisolated static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Context

    /// How many earlier parts are sent, and how long each one may be.
    private static let contextEntries = 15
    private static let contextCharacters = 300

    private static func userMessage(for reading: Reading, task: String) -> String {
        var message = "She is reading a \(reading.kind == .manga ? "manga" : "book") called “\(reading.title)”.\n"
        let earlier = reading.entries.suffix(contextEntries)
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
    You help a young reader who speaks English and is learning Japanese read a real Japanese book
    or manga. She shows you one short part at a time: either the text itself, or a picture (a crop
    of a page; for a manga, usually one panel). Be warm and clear, and accurate above all. Don't be
    babyish: explain real grammar, naming a grammar term only with a few simple words about what it does.

    Return:
    - "text": the Japanese text exactly as written. From a picture: read all the words in reading
      order (manga: speech bubbles right to left, top to bottom; vertical lines top to bottom), one
      bubble or sentence per line. Leave out small furigana printed beside kanji. Include sound
      effects only if they are clearly part of the text. If you were given the text, return it
      unchanged, except for stray spaces or line breaks inside a sentence. If there is no Japanese
      text, return an empty string.
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
      of the text is unclear or cut off, say so.
    - "words": the words and grammar pieces in order (at most 12; skip repeats): "japanese" as
      written, "reading" in hiragana, "meaning" in short English, "note" with its role in a few words
      (e.g. "topic particle", "past form of 食べる").
    - "kanji": each different kanji in the text: "kanji", "reading" (the reading used here, in
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
