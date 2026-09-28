import SwiftUI

/// Tab bar on iPhone; sidebar on iPad and Mac (`.sidebarAdaptable`).
struct RootView: View {
    @State private var model = AppModel()

    var body: some View {
        TabView(selection: $model.section) {
            Tab("Write", systemImage: "pencil.and.scribble", value: AppSection.write) {
                ContentView(model: model)
            }
            Tab("My words", systemImage: "book", value: AppSection.words) {
                HistoryView(history: model.history, style: model.settings.display) { word in
                    model.open(word)
                }
            }
            Tab("Learn", systemImage: "character.book.closed", value: AppSection.learn) {
                LearnView(model: model)
            }
            Tab("Settings", systemImage: "gearshape", value: AppSection.settings) {
                SettingsView(
                    settings: model.settings,
                    translator: model.translator,
                    history: model.history,
                    watchSync: model.watchSync,
                    isInTab: true
                )
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .task { await model.library.load() }
        .onChange(of: watchSyncKey, initial: true) {
            model.watchSync.update(history: model.history, settings: model.settings)
        }
    }

    /// Changes whenever something the watch shows changes.
    private var watchSyncKey: String {
        let settings = model.settings
        return [
            "\(model.history.revision)", "\(settings.syncToWatch)", settings.writingStyle.rawValue,
            "\(settings.kanjiLevel)", "\(settings.showRomaji)", "\(settings.showFurigana)",
        ].joined(separator: "|")
    }
}
