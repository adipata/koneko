import Foundation

/// A child-friendly explanation of a kanji, written by the AI and saved on the device.
nonisolated struct KanjiExplanation: Codable, Sendable, Equatable {
    nonisolated struct Example: Codable, Sendable, Hashable {
        var word: String
        var reading: String
        var meaning: String
    }

    var emoji: String
    var meaning: String
    var explanation: String
    var memoryTip: String
    var examples: [Example]
}

extension KanjiExplanation {
    /// The answer has something to show. Some models now and then answer with every text left
    /// empty; such an answer must not be saved, or the card stays blank for good.
    nonisolated var hasContent: Bool {
        !explanation.isEmpty || !memoryTip.isEmpty || !examples.isEmpty
    }

    /// Some models break the JSON: they close a text field too late, so the rest of the answer
    /// (`", "examples": [...]}`) ends up inside that text. This cuts the leaked JSON out of the
    /// texts and recovers the fields it held, so the card shows the word list, not raw JSON.
    /// It also tidies the examples (hiragana readings, drops words that aren't Japanese).
    nonisolated func repaired() -> KanjiExplanation {
        var result = self
        var leaked: [String: Any] = [:]
        result.emoji = Self.cutLeakedJSON(from: emoji, into: &leaked)
        result.meaning = Self.cutLeakedJSON(from: meaning, into: &leaked)
        result.explanation = Self.cutLeakedJSON(from: explanation, into: &leaked)
        result.memoryTip = Self.cutLeakedJSON(from: memoryTip, into: &leaked)

        if result.emoji.isEmpty, let value = leaked["emoji"] as? String { result.emoji = Self.trimmed(value) }
        if result.meaning.isEmpty, let value = leaked["meaning"] as? String { result.meaning = Self.trimmed(value) }
        if result.explanation.isEmpty, let value = leaked["explanation"] as? String { result.explanation = Self.trimmed(value) }
        if result.memoryTip.isEmpty, let value = leaked["memoryTip"] as? String { result.memoryTip = Self.trimmed(value) }
        if result.examples.isEmpty, let items = leaked["examples"] as? [[String: Any]] {
            result.examples = items.compactMap { item in
                guard let word = item["word"] as? String, let reading = item["reading"] as? String else { return nil }
                return Example(word: word, reading: reading, meaning: item["meaning"] as? String ?? "")
            }
        }

        result.examples = result.examples
            .map { Example(word: Self.trimmed($0.word), reading: JapaneseText.hiragana(Self.trimmed($0.reading)), meaning: Self.trimmed($0.meaning)) }
            .filter { JapaneseText.isKana($0.reading) && JapaneseText.isJapanese($0.word) }
        return result
    }

    /// Returns the text before a leaked `", "field":` marker, and parses the JSON after it into `leaked`.
    private nonisolated static func cutLeakedJSON(from text: String, into leaked: inout [String: Any]) -> String {
        // Undo leftover escaping (`\"`) so the marker is found whichever way the model wrote it.
        let plain = text.replacingOccurrences(of: "\\\"", with: "\"")
        let marker = #"\s*,\s*"(emoji|meaning|explanation|memoryTip|examples)"\s*:"#
        guard let found = plain.range(of: marker, options: .regularExpression),
              let keyStart = plain[found].firstIndex(of: "\"")
        else { return text }

        // The leaked part may or may not keep its closing brace; try a few endings.
        let tail = String(plain[keyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let body = tail.trimmingCharacters(in: CharacterSet(charactersIn: "}\" \n\t"))
        var parsed = false
        for candidate in ["{" + tail, "{" + tail + "}", "{" + body + "}", "{" + body + "\"}", "{" + body + "]}"] {
            if let object = try? JSONSerialization.jsonObject(with: Data(candidate.utf8)) as? [String: Any] {
                leaked.merge(object) { current, _ in current }
                parsed = true
                break
            }
        }
        // Still not valid JSON: pick the fields out one by one, so the texts aren't lost.
        if !parsed {
            leaked.merge(fieldsByPattern(in: tail)) { current, _ in current }
        }
        return trimmed(String(plain[..<found.lowerBound]))
    }

    /// Finds `"field": "text"` pairs and the `"examples": [...]` list in broken JSON.
    private nonisolated static func fieldsByPattern(in text: String) -> [String: Any] {
        var result: [String: Any] = [:]
        for field in ["emoji", "meaning", "explanation", "memoryTip"] {
            let pattern = "\"\(field)\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\""
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range(at: 1), in: text)
            else { continue }
            let value = String(text[range])
            // Undo JSON escapes (\n, \u3042, …) by decoding the text as a JSON string.
            let decoded = (try? JSONSerialization.jsonObject(with: Data("[\"\(value)\"]".utf8)) as? [String])?.first
            result[field] = decoded ?? value
        }
        if let start = text.range(of: #""examples"\s*:\s*\["#, options: .regularExpression),
           let end = text.range(of: "]", options: .backwards), end.lowerBound >= start.upperBound {
            let list = "[" + String(text[start.upperBound..<end.lowerBound]) + "]"
            if let items = try? JSONSerialization.jsonObject(with: Data(list.utf8)) as? [[String: Any]] {
                result["examples"] = items
            }
        }
        return result
    }

    /// Drops stray quotes, commas and spaces left around a cut text.
    private nonisolated static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”, \n\t"))
    }
}

/// Asks the AI to explain kanji (once each; answers are cached on the device).
@Observable
final class KanjiExplainer {
    private(set) var explanations: [String: KanjiExplanation] = [:]
    private(set) var loading: Set<String> = []
    private(set) var errors: [String: AIProblem] = [:]
    private let fileURL: URL

    init() {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appending(path: "kanji_explanations.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([String: KanjiExplanation].self, from: data) {
            // Repair answers saved before the leaked-JSON fix, so old broken cards fix themselves.
            // Empty answers saved by earlier versions are dropped, so they are asked for again.
            explanations = saved.mapValues { $0.repaired() }.filter { $0.value.hasContent }
            if explanations != saved { save() }
        }
    }

    func explain(_ info: KanjiInfo, model: AIModel) async {
        let key = info.character
        // Without an API key there is nothing to ask (the view says so).
        guard explanations[key] == nil, !loading.contains(key), let client = try? model.client() else { return }
        loading.insert(key)
        errors[key] = nil
        defer { loading.remove(key) }

        do {
            let result: KanjiExplanation = try await client.requestJSON(
                system: Self.systemPrompt,
                user: Self.userMessage(for: info),
                schemaName: "kanji_explanation",
                schema: Self.schema
            )
            let repaired = result.repaired()
            guard repaired.hasContent else {
                // Show "try again" instead of a blank card, and don't keep the empty answer.
                errors[key] = AIProblem(TranslationError.badResponse, provider: model.provider)
                return
            }
            explanations[key] = repaired
            save()
        } catch is CancellationError {
            return
        } catch {
            errors[key] = AIProblem(error, provider: model.provider)
        }
    }

    func forget(_ character: String) {
        explanations[character] = nil
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(explanations) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: Prompt

    private static let systemPrompt = """
    You explain Japanese kanji to a 9-year-old child who speaks English and is learning Japanese.
    Be warm, simple and accurate. Use short sentences and everyday words.

    Return:
    - "emoji": one emoji that best shows the meaning.
    - "meaning": the main meaning in 1 to 4 English words.
    - "explanation": 1 or 2 short sentences about what it means and when it is used.
    - "memoryTip": one short, fun way to remember the shape (what it looks like), true to the real shape.
      When the parts it is built from are given, a tip that joins their meanings works well.
    - "examples": 2 or 3 common, child-friendly words that use this kanji. "word" as normally written,
      "reading" in hiragana only, "meaning" in simple English.
    """

    private static func userMessage(for info: KanjiInfo) -> String {
        """
        Kanji: \(info.character)
        Dictionary meanings: \(info.meanings.joined(separator: ", "))
        Japanese readings (kun): \(info.kun.map(KanjiInfo.clean).joined(separator: ", "))
        Chinese readings (on): \(info.on.joined(separator: ", "))
        Strokes: \(info.strokes)
        \(partsLine(for: info))
        """
    }

    /// The parts the kanji is built from (from KanjiVG), so the memory tip matches the real shape.
    private static func partsLine(for info: KanjiInfo) -> String {
        let parts = KanjiParts.shared.parts(of: info.character)
        guard !parts.isEmpty else { return "" }
        let list = parts.map { "\($0.character) (\($0.meaning.lowercased()))" }.joined(separator: " + ")
        return "Built from: \(list)"
    }

    private static var schema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["emoji", "meaning", "explanation", "memoryTip", "examples"],
            "properties": [
                "emoji": ["type": "string"],
                "meaning": ["type": "string"],
                "explanation": ["type": "string"],
                "memoryTip": ["type": "string"],
                "examples": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["word", "reading", "meaning"],
                        "properties": [
                            "word": ["type": "string"],
                            "reading": ["type": "string"],
                            "meaning": ["type": "string"],
                        ],
                    ],
                ],
            ],
        ]
    }
}
