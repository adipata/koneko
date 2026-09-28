import SwiftUI

/// The app's main sections: a tab bar on iPhone, a sidebar on iPad and Mac.
enum AppSection: String, Hashable, CaseIterable {
    case write
    case words
    case learn
    case settings
}

/// Objects shared by all sections.
@Observable
final class AppModel {
    let library = StrokeLibrary()
    let translator = Translator()
    let settings = AppSettings()
    let speech = SpeechInput()
    let history = HistoryStore()
    let watchSync = WatchSyncController()
    let kanji = KanjiLibrary()
    let kanjiExplainer = KanjiExplainer()

    var section: AppSection = .write
    /// A word chosen in another section (e.g. My words) for the Write section to show.
    var wordToOpen: WordCandidate?

    func open(_ word: WordCandidate) {
        wordToOpen = word
        section = .write
    }
}
