import Foundation

/// The instructions and JSON schema sent to the LLM.
nonisolated enum TranslationPrompt {
    static let system = """
    You help a 9-year-old child who speaks English learn to read and write Japanese.
    You receive a word or short phrase and return Japanese words the child might mean.

    Rules:
    - Return 1 to 4 candidates, most likely first.
    - Prefer the common, everyday word a Japanese child would learn first.
    - If the input has several common meanings (for example "bat" or "light"), give one candidate per meaning.
    - "japanese": how the word is normally written by adults, using kanji, hiragana and/or katakana as is natural. Loanwords are written in katakana.
    - "reading": the full reading in hiragana only, even for katakana words.
    - "romaji": Hepburn romanization, lowercase.
    - "meaning": a short, simple English gloss for a child (at most 8 words).
    - "explanation": 2 to 4 short, simple English sentences for a child: what the word or expression really means, when and how Japanese people use it, and 1 or 2 example words or phrases written in Japanese with their reading and meaning in brackets, e.g. 巻き寿司 (まきずし, rolled sushi). For a single kanji, say what idea it stands for (for example "巻 is about something rolled up, wrapped or wound around") and give common words that use it.
    - "emoji": one emoji that shows the meaning.
    - "isLoanword": true if the word is a loanword written in katakana.
    - "parts": split "japanese" into consecutive pieces. Each piece containing kanji gets its hiragana reading; each kana piece gets its own reading in hiragana. Joining the "text" of all parts must give exactly "japanese".
    - For a short phrase, give a natural, simple translation.
    - A single kanji is always valid input, even if it is rarely used alone: return it as the candidate ("japanese" is the kanji itself), with its most common reading (prefer the kun'yomi when the kanji has one, e.g. 巻 → まき), and explain its meaning.
    - Any real Japanese word, kanji or expression is valid input, even if it is unusual or not a word a child would learn first.
    - Japanese input written only in hiragana or katakana is valid even when adults normally write the word with kanji. Look it up by its sound and return the usual written form, e.g. やまぶどう → 山ぶどう (wild grape), さくら → 桜, ねこ → 猫.
    - Kana input may be a compound of known words (やま + ぶどう, うみ + がめ). If you don't know it as a single dictionary word, split it into the words it is made of and combine their meanings.
    - If the input looks misspelled or misheard, guess the intended word.
    - Only return an empty candidates list if the input is meaningless (random letters or noise) or not suitable for a child. Never return an empty list just because a word is written in kana instead of kanji.
    """

    static func userMessage(for text: String, language: InputLanguage) -> String {
        switch language {
        case .english:
            "English input: \(text)"
        case .japanese:
            """
            Japanese input (may be hiragana, katakana, kanji or romaji, and may come from speech recognition): \(text)
            Return how it is written. If it sounds like several different words (homophones), give one candidate per word.
            """
        }
    }

    /// Asked once more when kana-only input came back with no words: kana spellings of words
    /// usually written with kanji (やまぶどう for 山ぶどう) are easy for a model to give up on.
    static func kanaRetryMessage(for text: String) -> String {
        """
        Japanese input written only in kana: \(text)
        This is a real Japanese word or phrase spelled by its sound. Adults may usually write it with kanji: find the word that is read "\(JapaneseText.hiragana(text))" and return it in its usual written form, with its meaning. If it is a compound, split it into the words it is made of (for example やまぶどう = やま 山 + ぶどう, wild grape) and combine their meanings. Do not return an empty list.
        """
    }

    static var schema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["candidates"],
            "properties": [
                "candidates": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["japanese", "reading", "romaji", "meaning", "explanation", "emoji", "isLoanword", "parts"],
                        "properties": [
                            "japanese": ["type": "string"],
                            "reading": ["type": "string"],
                            "romaji": ["type": "string"],
                            "meaning": ["type": "string"],
                            "explanation": ["type": "string"],
                            "emoji": ["type": "string"],
                            "isLoanword": ["type": "boolean"],
                            "parts": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "additionalProperties": false,
                                    "required": ["text", "reading"],
                                    "properties": [
                                        "text": ["type": "string"],
                                        "reading": ["type": "string"],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ]
    }
}
