import SwiftUI

/// User preferences, stored in UserDefaults. (The API key lives in the Keychain.)
@Observable
final class AppSettings {
    struct ModelOption: Identifiable, Hashable {
        let id: String
        let name: String
        let note: String
    }

    static let modelOptions = [
        ModelOption(id: "google/gemini-3.7-flash", name: "Gemini 3.7 Flash", note: "Recommended: fast and good at Japanese"),
        ModelOption(id: "google/gemini-3.6-flash", name: "Gemini 3.6 Flash", note: "Previous Flash version"),
        ModelOption(id: "openai/gpt-5-mini", name: "GPT-5 mini", note: "Cheaper, a bit slower"),
        ModelOption(id: "deepseek/deepseek-v3.2", name: "DeepSeek V3.2", note: "Very cheap"),
    ]

    private enum Keys {
        static let model = "model"
        static let inputLanguage = "inputLanguage"
        static let showRomaji = "showRomaji"
        static let speakAutomatically = "speakAutomatically"
        static let syncToWatch = "syncToWatch"
        static let writingStyle = "writingStyle"
        static let kanjiLevel = "kanjiLevel"
        static let showFurigana = "showFurigana"
    }

    private let defaults = UserDefaults.standard

    var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    var inputLanguage: InputLanguage {
        didSet { defaults.set(inputLanguage.rawValue, forKey: Keys.inputLanguage) }
    }

    var showRomaji: Bool {
        didSet { defaults.set(showRomaji, forKey: Keys.showRomaji) }
    }

    var speakAutomatically: Bool {
        didSet { defaults.set(speakAutomatically, forKey: Keys.speakAutomatically) }
    }

    /// Share My words with the Apple Watch app through iCloud.
    var syncToWatch: Bool {
        didSet { defaults.set(syncToWatch, forKey: Keys.syncToWatch) }
    }

    var writingStyle: WritingStyle {
        didSet { defaults.set(writingStyle.rawValue, forKey: Keys.writingStyle) }
    }

    /// 0 = no kanji yet, 1–6 = school grade, 7 = all jōyō kanji.
    var kanjiLevel: Int {
        didSet { defaults.set(kanjiLevel, forKey: Keys.kanjiLevel) }
    }

    var showFurigana: Bool {
        didSet { defaults.set(showFurigana, forKey: Keys.showFurigana) }
    }

    /// The word as it should appear on screen with the current writing settings.
    func display(_ word: WordCandidate) -> WordCandidate {
        writingStyle.apply(to: word, kanjiLevel: kanjiLevel)
    }

    init() {
        model = defaults.string(forKey: Keys.model) ?? Self.modelOptions[0].id
        inputLanguage = defaults.string(forKey: Keys.inputLanguage).flatMap { InputLanguage(rawValue: $0) } ?? .english
        showRomaji = defaults.object(forKey: Keys.showRomaji) as? Bool ?? true
        speakAutomatically = defaults.object(forKey: Keys.speakAutomatically) as? Bool ?? true
        syncToWatch = defaults.bool(forKey: Keys.syncToWatch)
        writingStyle = defaults.string(forKey: Keys.writingStyle).flatMap { WritingStyle(rawValue: $0) } ?? .schoolLevel
        kanjiLevel = defaults.object(forKey: Keys.kanjiLevel) as? Int ?? 1
        showFurigana = defaults.object(forKey: Keys.showFurigana) as? Bool ?? true
    }
}
