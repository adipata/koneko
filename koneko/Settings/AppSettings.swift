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

    init() {
        model = defaults.string(forKey: Keys.model) ?? Self.modelOptions[0].id
        inputLanguage = defaults.string(forKey: Keys.inputLanguage).flatMap { InputLanguage(rawValue: $0) } ?? .english
        showRomaji = defaults.object(forKey: Keys.showRomaji) as? Bool ?? true
        speakAutomatically = defaults.object(forKey: Keys.speakAutomatically) as? Bool ?? true
    }
}
