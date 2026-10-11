#if os(iOS)
import UIKit

/// Advice on a word she wrote by hand for an English → 日本語 flash card: the AI (OpenRouter)
/// looks at the cropped photo and compares it with the card's word, first the word as a whole,
/// then the shape of each character.
nonisolated struct HandwritingAdvice: Decodable, Sendable {
    struct CharacterAdvice: Decodable, Sendable, Hashable {
        let character: String
        let advice: String
    }

    /// What she wrote, as the AI reads it.
    let read: String
    /// She wrote the card's word (in any accepted script).
    let rightWord: Bool
    /// About the word itself: right word, missing, extra or swapped characters, small kana, ゛ ゜, long vowels.
    let word: String
    /// How each character is formed.
    let characters: [CharacterAdvice]
    /// One short, kind closing line.
    let overall: String
}

enum HandwritingCoach {
    static func check(_ image: UIImage, card: FlashCard, model: String) async throws -> HandwritingAdvice {
        guard let apiKey = Keychain.apiKey, !apiKey.isEmpty else { throw TranslationError.missingAPIKey }
        guard let jpeg = image.jpegData(compressionQuality: 0.8) else { throw TranslationError.badResponse }
        let client = OpenRouterClient(apiKey: apiKey, model: model)
        var user = """
        The flash card showed the English: \(card.english)
        The expected Japanese word: \(card.japanese)
        """
        if let detail = card.detail {
            user += "\nReading and romaji: \(detail)"
        }
        user += "\nThe photo shows what she wrote by hand. Check it."
        return try await client.requestJSON(
            system: systemPrompt,
            user: user,
            imageJPEG: jpeg,
            schemaName: "handwriting_advice",
            schema: schema
        )
    }

    private static let systemPrompt = """
    You are a kind Japanese handwriting teacher for a 9-year-old child. She saw an English word
    on a flash card and wrote the Japanese word by hand on paper. You get the expected word and a
    photo of her writing. Answer in simple English, short sentences, warm and encouraging, never
    harsh. Be honest: if something is wrong, say what and how to fix it.

    Work from the big picture down to the details:
    1. "read": exactly what she wrote, as you read it (kana or kanji, no romaji). Empty if you
       can't find any writing.
    2. "rightWord": true if she wrote the expected word. Writing a kanji word fully in hiragana,
       or with fewer kanji, still counts as right.
    3. "word": about the word as a whole. Is it the right word? Any missing, extra, swapped or
       wrong characters? Hiragana where katakana is expected or the other way round? Small kana
       (っ ゃ ゅ ょ), dakuten ゛ and handakuten ゜, long vowels (ー, おう, えい)? If she used
       hiragana for a kanji, say it's fine and mention the kanji gently. If the word is right,
       say so in one sentence.
    4. "characters": one entry per character she wrote, in order, with "advice" on its form:
       the shape and proportions, stroke length and angle, where strokes meet or cross or should
       stay apart, endings (stop, hook, sweep: とめ, はね, はらい), balance and size compared with
       the other characters, and characters that look like another one (e.g. シ and ツ, ソ and ン,
       ぬ and め, は and ほ). One or two sentences each. If a character is well written, say what is
       good about it. Don't guess stroke order: a photo can't show it.
    5. "overall": one short, kind sentence to end with, e.g. what to practise next.
    """

    private static var schema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["read", "rightWord", "word", "characters", "overall"],
            "properties": [
                "read": ["type": "string"],
                "rightWord": ["type": "boolean"],
                "word": ["type": "string"],
                "characters": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["character", "advice"],
                        "properties": [
                            "character": ["type": "string"],
                            "advice": ["type": "string"],
                        ],
                    ],
                ],
                "overall": ["type": "string"],
            ],
        ]
    }
}
#endif
