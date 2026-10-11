import SwiftUI

/// Icon-only button that copies `text`; the icon turns into a checkmark for a moment to
/// show it worked.
struct CopyButton: View {
    let text: String

    @State private var copied = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        Button {
            Clipboard.copy(text)
            copied = true
            resetTask?.cancel()
            resetTask = Task {
                try? await Task.sleep(for: .seconds(1.5))
                guard !Task.isCancelled else { return }
                copied = false
            }
        } label: {
            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                .contentTransition(.symbolEffect(.replace))
        }
        .help("Copy “\(text)”")
        .accessibilityLabel(copied ? "Copied \(text)" : "Copy \(text)")
        .animation(.default, value: copied)
        // A different symbol was selected: don't keep showing the checkmark for the old one.
        .onChange(of: text) {
            resetTask?.cancel()
            copied = false
        }
    }
}
