import SwiftUI

/// The app's search/input box, used the same way on every screen: a rounded field with a
/// magnifying glass, the text, and a clear button.
struct SearchField: View {
    let prompt: String
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    var onSubmit: () -> Void = {}
    /// Custom clear action (default: empty the text and hide the keyboard).
    var onClear: (() -> Void)?
    /// Show the clear button also while focused (for Japanese text still being composed).
    var showsClearWhileFocused = false
    /// Changing it recreates the text field (drops half-typed Japanese).
    var resetID = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .font(.title3)
                .autocorrectionDisabled()
                .focused(focus)
                .submitLabel(.search)
                .onSubmit(onSubmit)
                .id(resetID)
            if !text.isEmpty || (showsClearWhileFocused && focus.wrappedValue) {
                Button("Clear", systemImage: "xmark.circle.fill") {
                    if let onClear {
                        onClear()
                    } else {
                        text = ""
                        focus.wrappedValue = false
                    }
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.tertiary)
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(focus.wrappedValue ? Color.orange.opacity(0.7) : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.15), value: focus.wrappedValue)
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }
}
