import SwiftUI

@main struct MyApp: App {
    init() {
        HandwritingFont.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
