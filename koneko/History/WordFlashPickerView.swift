import SwiftUI

/// Where flash-card words come from: all her words, the pinned ones, or a folder.
enum WordFlashSource: Hashable {
    case all
    case pinned
    case folder(UUID)

    func includes(_ entry: HistoryEntry) -> Bool {
        switch self {
        case .all: true
        case .pinned: entry.isPinned
        case .folder(let id): entry.folderID == id
        }
    }
}

/// Flash cards from My words: tick one or more folders (or All words / Pinned), then Start.
struct WordFlashPickerView: View {
    let history: HistoryStore
    let style: (WordCandidate) -> WordCandidate
    let kanji: KanjiLibrary

    @State private var sources: Set<WordFlashSource>
    @Environment(\.dismiss) private var dismiss
    @State private var activeDeck: FlashDeck?

    /// `sources`: what's ticked at first (the folder or list she was looking at).
    init(history: HistoryStore, style: @escaping (WordCandidate) -> WordCandidate, kanji: KanjiLibrary, sources: Set<WordFlashSource>) {
        self.history = history
        self.style = style
        self.kanji = kanji
        _sources = State(initialValue: sources)
    }

    /// The ticked words, in My words order, each word once.
    private var entries: [HistoryEntry] {
        history.entries.filter { entry in sources.contains { $0.includes(entry) } }
    }

    private func title(of source: WordFlashSource) -> String {
        switch source {
        case .all: "All my words"
        case .pinned: "📌 Pinned"
        case .folder(let id): "📁 " + (history.folders.first { $0.id == id }?.name ?? "Folder")
        }
    }

    /// Sources in the order they're listed, for the deck title.
    private var orderedSources: [WordFlashSource] {
        let listed: [WordFlashSource] = [.all, .pinned] + history.folders.map { WordFlashSource.folder($0.id) }
        return listed.filter { sources.contains($0) }
    }

    private var deck: FlashDeck {
        let names = orderedSources.map { title(of: $0) }
        let deckTitle = names.count <= 3 ? names.joined(separator: " + ") : "\(names.count) folders"
        return .words(title: deckTitle, words: entries.map { style($0.word) })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(.all, count: history.entries.count)
                    row(.pinned, count: history.entries.filter(\.isPinned).count)
                }
                if !history.folders.isEmpty {
                    Section {
                        ForEach(history.folders) { folder in
                            row(.folder(folder.id), count: history.count(in: folder))
                        }
                    } header: {
                        Text("Folders")
                    } footer: {
                        Text("Tick one folder, or several to mix their words.")
                    }
                }
            }
            .navigationTitle("🃏 Word flash cards")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                let count = entries.count
                Button {
                    activeDeck = deck
                } label: {
                    Label(count == 1 ? "Start · 1 word" : "Start · \(count) words", systemImage: "play.fill")
                        .frame(maxWidth: 420)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(count == 0)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
            .sheet(item: $activeDeck) { deck in
                FlashCardSessionView(deck: deck, kanji: kanji)
                    #if os(macOS)
                    .frame(minWidth: 480, minHeight: 640)
                    #endif
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }

    private func row(_ source: WordFlashSource, count: Int) -> some View {
        let isChecked = sources.contains(source)
        return Button {
            if isChecked { sources.remove(source) } else { sources.insert(source) }
        } label: {
            HStack {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? Color.accentColor : .secondary)
                    .font(.title3)
                Text(title(of: source))
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}
