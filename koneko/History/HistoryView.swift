import SwiftUI

/// "My words": everything she looked up, to open and practise again.
struct HistoryView: View {
    let history: HistoryStore
    let style: (WordCandidate) -> WordCandidate
    let onSelect: (WordCandidate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            Group {
                if history.entries.isEmpty {
                    ContentUnavailableView(
                        "No words yet",
                        systemImage: "book",
                        description: Text("Words you look up will appear here.")
                    )
                } else {
                    List {
                        ForEach(history.entries) { entry in
                            Button {
                                onSelect(entry.word)
                                dismiss()
                            } label: {
                                row(entry)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: history.delete)
                    }
                }
            }
            .navigationTitle("My words")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear", role: .destructive) { confirmClear = true }
                        .disabled(history.entries.isEmpty)
                }
            }
            .confirmationDialog("Remove all words from the list?", isPresented: $confirmClear) {
                Button("Remove all", role: .destructive) { history.removeAll() }
            }
            #if os(macOS)
            .frame(minWidth: 460, minHeight: 520)
            #endif
        }
    }

    private func row(_ entry: HistoryEntry) -> some View {
        let word = style(entry.word)
        return HStack(spacing: 14) {
            Text(word.emoji.isEmpty ? "📝" : word.emoji)
                .font(.largeTitle)
            VStack(alignment: .leading, spacing: 2) {
                Text(word.japanese)
                    .font(.handwriting(size: 30))
                if !word.meaning.isEmpty {
                    Text(word.meaning)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if entry.totalStars > 0 {
                Text("⭐️ \(entry.totalStars)")
                    .font(.headline)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}
