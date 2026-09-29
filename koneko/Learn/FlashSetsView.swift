import SwiftUI

/// Flash cards menu for one kind (hiragana, katakana or kanji): the default "all" deck and
/// her own sets, which can be started, edited, renamed and deleted.
struct FlashSetsView: View {
    let kind: FlashSetKind
    let kanjiGrade: Int
    let store: FlashSetStore
    let kanji: KanjiLibrary
    /// Close this menu and pick symbols in the chart (nil = a new set).
    let editSymbols: (FlashSet?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var activeDeck: FlashDeck?
    @State private var renaming: FlashSet?
    @State private var newName = ""
    @State private var deleting: FlashSet?

    private var defaultDeck: FlashDeck {
        switch kind {
        case .hiragana: .kana(.hiragana)
        case .katakana: .kana(.katakana)
        case .kanji: .kanji(grade: kanjiGrade)
        }
    }

    private var defaultTitle: String {
        switch kind {
        case .hiragana: "All hiragana"
        case .katakana: "All katakana"
        case .kanji: kanjiGrade == 7 ? "All kanji · Secondary" : "All kanji · Grade \(kanjiGrade)"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(title: defaultTitle, count: defaultDeck.cards(kanji: kanji).count, icon: "square.stack.3d.up.fill") {
                        activeDeck = defaultDeck
                    }
                }

                Section {
                    ForEach(store.sets(of: kind)) { set in
                        row(title: set.name, count: set.items.count, icon: "rectangle.on.rectangle.angled") {
                            activeDeck = .custom(set)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) { deleting = set }
                            Button("Edit", systemImage: "checklist") { edit(set) }
                                .tint(.blue)
                        }
                        .contextMenu {
                            Button("Edit symbols", systemImage: "checklist") { edit(set) }
                            Button("Rename", systemImage: "pencil") {
                                newName = set.name
                                renaming = set
                            }
                            Divider()
                            Button("Delete", systemImage: "trash", role: .destructive) { deleting = set }
                        }
                    }
                    Button("New set…", systemImage: "plus.circle.fill") { edit(nil) }
                } header: {
                    Text("My sets")
                } footer: {
                    Text("Tap New set, then tick the symbols in the chart, like selecting photos. Tap a row letter (k, s…) or column (a, i…) to tick a whole row or column. Long-press a set to edit, rename or delete it.")
                }
            }
            .navigationTitle("🃏 \(kind.title) flash cards")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $activeDeck) { deck in
                FlashCardSessionView(deck: deck, kanji: kanji)
                    #if os(macOS)
                    .frame(minWidth: 480, minHeight: 640)
                    #endif
            }
            .alert("Rename set", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Rename") {
                    if let set = renaming { store.rename(set.id, to: newName) }
                    renaming = nil
                }
            }
            .confirmationDialog(
                "Delete “\(deleting?.name ?? "")”?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete set", role: .destructive) {
                    if let set = deleting { store.delete(set.id) }
                    deleting = nil
                }
            } message: {
                Text("Only the set is deleted, not the symbols.")
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }

    private func row(title: String, count: Int, icon: String, start: @escaping () -> Void) -> some View {
        Button(action: start) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
    }

    private func edit(_ set: FlashSet?) {
        dismiss()
        editSymbols(set)
    }
}

/// Bar shown at the bottom in Select mode: Cancel · "12 selected" · Save.
struct SelectionBar: View {
    let count: Int
    let isEditing: Bool
    let cancel: () -> Void
    let clear: () -> Void
    let save: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: cancel)
            Spacer()
            VStack(spacing: 0) {
                Text(count == 1 ? "1 selected" : "\(count) selected")
                    .font(.headline)
                    .monospacedDigit()
                if count > 0 {
                    Button("Clear", action: clear)
                        .font(.caption)
                }
            }
            Spacer()
            Button(isEditing ? "Save" : "Save as set…", action: save)
                .buttonStyle(.borderedProminent)
                .disabled(count == 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
