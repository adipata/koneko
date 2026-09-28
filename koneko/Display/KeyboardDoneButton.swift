import SwiftUI

extension View {
    /// Adds a "Done" button above the on-screen keyboard (iPhone/iPad), so it can always be
    /// closed, which brings back the tab bar.
    func keyboardDoneButton(_ action: @escaping () -> Void) -> some View {
        #if os(iOS)
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done", action: action)
            }
        }
        #else
        self
        #endif
    }
}
