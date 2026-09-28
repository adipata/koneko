import SwiftUI

@main
struct KonekoWatchApp: App {
    @State private var store = WatchStore()
    @State private var kanji = KanjiLibrary()

    var body: some Scene {
        WindowGroup {
            WatchWordListView(store: store, kanji: kanji)
        }
    }
}
