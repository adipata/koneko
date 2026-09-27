#if os(watchOS)
// Watch app only. If this folder is accidentally added to the iPhone/iPad/Mac target,
// this file compiles to nothing instead of breaking the build.
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
#endif
