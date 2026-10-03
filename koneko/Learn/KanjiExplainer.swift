import Foundation

/// A child-friendly explanation of a kanji, written by the AI and saved on the device.
nonisolated struct KanjiExplanation: Codable, Sendable {
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

/// Asks OpenRouter to explain kanji (once each; answers are cached on the device).
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
            explanations = saved
        }
    }

    var hasAPIKey: Bool { !(Keychain.apiKey ?? "").isEmpty }

    func explain(_ info: KanjiInfo, model: String) async {
        let key = info.character
        guard explanations[key] == nil, !loading.contains(key), let apiKey = Keychain.apiKey, !apiKey.isEmpty else { return }
        loading.insert(key)
        errors[key] = nil
        defer { loading.remove(key) }

        let client = OpenRouterClient(apiKey: apiKey, model: model)
        do {
            var result: KanjiExplanation = try await client.requestJSON(
                system: Self.systemPrompt,
                user: Self.userMessage(for: info),
                schemaName: "kanji_explanation",
                schema: Self.schema
            )
            result.examples = result.examples
                .map { .init(word: $0.word, reading: JapaneseText.hiragana($0.reading), meaning: $0.meaning) }
                .filter { JapaneseText.isKana($0.reading) && JapaneseText.isJapanese($0.word) }
            explanations[key] = result
            save()
        } catch is CancellationError {
            return
        } catch {
            errors[key] = AIProblem(error)
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
        """
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
