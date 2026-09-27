import SwiftUI

@main
struct KonekoWatchApp: App {
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            WatchWordListView(store: store)
        }
    }
}
