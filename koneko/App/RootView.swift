import SwiftUI

/// Tab bar on iPhone; sidebar on iPad and Mac (`.sidebarAdaptable`).
struct RootView: View {
    @State private var model = AppModel()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            tabs
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
                    .onTapGesture { hideSplash() }
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2.4))
            hideSplash()
        }
    }

    private func hideSplash() {
        guard showSplash else { return }
        withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
    }

    private var tabs: some View {
        TabView(selection: $model.section) {
            Tab("Write", systemImage: "pencil.and.scribble", value: AppSection.write) {
                ContentView(model: model)
            }
            Tab("My words", systemImage: "book", value: AppSection.words) {
                HistoryView(
                    history: model.history,
                    style: model.settings.display,
                    onSelect: { model.open($0) },
                    showRomaji: model.settings.showRomaji
                )
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
