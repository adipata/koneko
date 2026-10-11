import Combine
import SwiftUI

/// Tab bar on iPhone; sidebar on iPad and Mac (`.sidebarAdaptable`).
struct RootView: View {
    @State private var model = AppModel()
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

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
                    showRomaji: model.settings.showRomajiInLists,
                    kanji: model.kanji
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
                    reviews: model.reviews,
                    isInTab: true
                )
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // Flash-card sessions (opened from Learn and My words) read these.
        .environment(model.reviews)
        .environment(model.settings)
        .task { await model.library.load() }
        .onChange(of: watchSyncKey, initial: true) {
            model.watchSync.update(history: model.history, settings: model.settings, flashSets: model.flashSets.sets)
        }
        .task(id: reviewsSyncKey) {
            // Wait for a pause, so a Review session sends its answers in one go, not card by card.
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            model.watchSync.updateReviews(model.reviews, settings: model.settings)
        }
        // Answers she gave on the watch.
        .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification).receive(on: DispatchQueue.main)) { _ in
            collectWatchAnswers()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                NSUbiquitousKeyValueStore.default.synchronize()
                collectWatchAnswers()
            }
        }
    }

    private func collectWatchAnswers() {
        model.watchSync.collectAnswers(into: model.reviews, settings: model.settings)
    }

    /// Changes whenever the review progress the watch gets changes.
    private var reviewsSyncKey: String {
        let settings = model.settings
        return "\(model.reviews.revision)|\(settings.syncToWatch)|\(settings.smartReview)|\(settings.newCardsPerDay)"
    }

    /// Changes whenever something the watch shows changes.
    private var watchSyncKey: String {
        let settings = model.settings
        return [
            "\(model.history.revision)", "\(settings.syncToWatch)", settings.writingStyle.rawValue,
            "\(settings.kanjiLevel)", "\(settings.showRomaji)", "\(settings.showFurigana)",
            "\(settings.showRomajiInLists)", "\(model.flashSets.revision)",
        ].joined(separator: "|")
    }
}
