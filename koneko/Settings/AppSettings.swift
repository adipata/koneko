import SwiftUI

/// User preferences, stored in UserDefaults. (The API keys live in the Keychain.)
@Observable
final class AppSettings {
    private enum Keys {
        static let provider = "aiProvider"
        static let model = "model"
        static let claudeModel = "claudeModel"
        static let inputLanguage = "inputLanguage"
        static let showRomaji = "showRomaji"
        static let showRomajiInLists = "showRomajiInLists"
        static let speakAutomatically = "speakAutomatically"
        static let syncToWatch = "syncToWatch"
        static let writingStyle = "writingStyle"
        static let kanjiLevel = "kanjiLevel"
        static let showFurigana = "showFurigana"
        static let smartReview = "smartReview"
        static let newCardsPerDay = "newCardsPerDay"
        static let englishOnlyWordPrompts = "englishOnlyWordPrompts"
    }

    private let defaults = UserDefaults.standard

    /// The AI service in use (OpenRouter or the Claude API). Its key is in the Keychain.
    var provider: AIProvider {
        didSet { defaults.set(provider.rawValue, forKey: Keys.provider) }
    }

    /// The OpenRouter model.
    var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }

    /// The Claude model.
    var claudeModel: String {
        didSet { defaults.set(claudeModel, forKey: Keys.claudeModel) }
    }

    /// The model of the chosen service (each service remembers its own).
    var currentModel: String {
        get { provider == .claude ? claudeModel : model }
        set {
            if provider == .claude { claudeModel = newValue } else { model = newValue }
        }
    }

    /// The chosen service and model, ready to ask.
    var aiModel: AIModel {
        AIModel(provider: provider, id: currentModel)
    }

    /// A key is saved for the chosen service.
    var hasAPIKey: Bool {
        !(Keychain.apiKey(for: provider) ?? "").isEmpty
    }

    var inputLanguage: InputLanguage {
        didSet { defaults.set(inputLanguage.rawValue, forKey: Keys.inputLanguage) }
    }

    var showRomaji: Bool {
        didSet { defaults.set(showRomaji, forKey: Keys.showRomaji) }
    }

    /// Romaji next to each word in My words (and the watch's word list).
    var showRomajiInLists: Bool {
        didSet { defaults.set(showRomajiInLists, forKey: Keys.showRomajiInLists) }
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

    /// Flash cards offer Review (spaced repetition) as well as Free practice.
    var smartReview: Bool {
        didSet { defaults.set(smartReview, forKey: Keys.smartReview) }
    }

    /// How many cards she hasn't met yet Review adds per deck each day.
    var newCardsPerDay: Int {
        didSet { defaults.set(newCardsPerDay, forKey: Keys.newCardsPerDay) }
    }

    /// English → 日本語 word cards (My words) show only the English on the front; the reading
    /// and romaji move to the Japanese side.
    var englishOnlyWordPrompts: Bool {
        didSet { defaults.set(englishOnlyWordPrompts, forKey: Keys.englishOnlyWordPrompts) }
    }

    /// The chosen model, or the service's default one if it can't read photos.
    var imageModel: AIModel {
        let chosen = provider.modelOptions.first { $0.id == currentModel }
        return AIModel(provider: provider, id: chosen?.readsImages == false ? provider.defaultModel : currentModel)
    }

    /// The word as it should appear on screen with the current writing settings.
    func display(_ word: WordCandidate) -> WordCandidate {
        writingStyle.apply(to: word, kanjiLevel: kanjiLevel)
    }

    init() {
        provider = defaults.string(forKey: Keys.provider).flatMap { AIProvider(rawValue: $0) } ?? .openRouter
        model = defaults.string(forKey: Keys.model) ?? AIProvider.openRouter.defaultModel
        claudeModel = defaults.string(forKey: Keys.claudeModel) ?? AIProvider.claude.defaultModel
        inputLanguage = defaults.string(forKey: Keys.inputLanguage).flatMap { InputLanguage(rawValue: $0) } ?? .english
        showRomaji = defaults.object(forKey: Keys.showRomaji) as? Bool ?? true
        showRomajiInLists = defaults.object(forKey: Keys.showRomajiInLists) as? Bool ?? true
        speakAutomatically = defaults.object(forKey: Keys.speakAutomatically) as? Bool ?? true
        syncToWatch = defaults.bool(forKey: Keys.syncToWatch)
        writingStyle = defaults.string(forKey: Keys.writingStyle).flatMap { WritingStyle(rawValue: $0) } ?? .schoolLevel
        kanjiLevel = defaults.object(forKey: Keys.kanjiLevel) as? Int ?? 1
        showFurigana = defaults.object(forKey: Keys.showFurigana) as? Bool ?? true
        smartReview = defaults.object(forKey: Keys.smartReview) as? Bool ?? true
        newCardsPerDay = defaults.object(forKey: Keys.newCardsPerDay) as? Int ?? 8
        englishOnlyWordPrompts = defaults.bool(forKey: Keys.englishOnlyWordPrompts)
    }
}
