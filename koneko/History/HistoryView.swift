import SwiftUI

/// "My words": her dictionary, with pinned words and folders (categories).
struct HistoryView: View {
    let history: HistoryStore
    let style: (WordCandidate) -> WordCandidate
    let onSelect: (WordCandidate) -> Void
    var showRomaji = true
    /// Needed by the flash-card screen (not used for words themselves).
    var kanji: KanjiLibrary?

    private enum Filter: Hashable {
        case all
        case pinned
        case folder(UUID)
    }

    @State private var filter = Filter.all
    @State private var searchText = ""
    @State private var flashDeck: FlashDeck?
    /// Choosing folders for word flash cards.
    @State private var showWordFlashPicker = false
    /// Select mode: the ids of the ticked words (nil = not selecting).
    @State private var picking: Set<String>?
    @State private var confirmDeleteSelected = false

    /// Flash cards for what's on screen: the search results, or the chosen folder / pinned / all.
    private var currentDeck: FlashDeck {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let entries = query.isEmpty ? filtered : history.entries.searched(query)
        let title: String
        if !query.isEmpty {
            title = "“\(query)”"
        } else {
            switch filter {
            case .all: title = "All my words"
            case .pinned: title = "📌 Pinned"
            case .folder(let id): title = "📁 " + (history.folders.first { $0.id == id }?.name ?? "Folder")
            }
        }
        return .words(title: title, words: entries.map { style($0.word) })
    }

    // Folder create / rename
    @State private var showFolderNameAlert = false
    @State private var folderName = ""
    @State private var renamingFolder: WordFolder?
    /// Words to put into the folder that's being created.
    @State private var entriesForNewFolder: Set<String> = []
    @State private var folderToDelete: WordFolder?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                Divider()
                content
            }
            .navigationTitle("My words")
            .searchable(text: $searchText, prompt: "Search in English")
            .toolbar {
                if picking == nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Select", systemImage: "checkmark.circle") { picking = [] }
                            .disabled(history.entries.isEmpty)
                            .help("Select several words, e.g. to put them in a folder")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        let isSearching = !searchText.trimmingCharacters(in: .whitespaces).isEmpty
                        let deck = currentDeck
                        Button("Flash cards", systemImage: "rectangle.on.rectangle.angled") {
                            // Search results start straight away; otherwise choose folders first.
                            if isSearching { flashDeck = deck } else { showWordFlashPicker = true }
                        }
                        .labelStyle(.titleAndIcon)
                        .disabled(kanji == nil || (isSearching ? deck.cards(kanji: KanjiLibrary.empty).isEmpty : history.entries.isEmpty))
                        .help("Practise words with flash cards, from one folder or several")
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        let ids = Set(visibleEntries.map(\.id))
                        let allTicked = !ids.isEmpty && ids.isSubset(of: picking ?? [])
                        Button(allTicked ? "Deselect all" : "Select all") {
                            picking = allTicked ? [] : ids
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let picking {
                    selectionBar(picking)
                }
            }
            .confirmationDialog(
                "Delete \(picking?.count ?? 0) words?",
                isPresented: $confirmDeleteSelected,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let picking { history.delete(picking) }
                    picking = nil
                }
            }
            .sheet(item: $flashDeck) { deck in
                if let kanji {
                    FlashCardSessionView(deck: deck, kanji: kanji)
                        #if os(macOS)
                        .frame(minWidth: 480, minHeight: 640)
                        #endif
                }
            }
            .sheet(isPresented: $showWordFlashPicker) {
                if let kanji {
                    WordFlashPickerView(history: history, style: style, kanji: kanji, sources: [flashSource])
                }
            }
            .alert(renamingFolder == nil ? "New folder" : "Rename folder", isPresented: $showFolderNameAlert) {
                TextField("e.g. 🐾 Animals", text: $folderName)
                Button("Cancel", role: .cancel) { resetFolderEditing() }
                Button(renamingFolder == nil ? "Create" : "Rename") { commitFolderName() }
            }
            .confirmationDialog(
                "Delete the folder “\(folderToDelete?.name ?? "")”?",
                isPresented: Binding(get: { folderToDelete != nil }, set: { if !$0 { folderToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete folder", role: .destructive) {
                    if let folder = folderToDelete {
                        picking = nil
                        if filter == .folder(folder.id) { filter = .all }
                        history.delete(folder)
                    }
                    folderToDelete = nil
                }
            } message: {
                Text("The words stay in “All words”.")
            }
        }
    }

    /// The list on screen, ticked first when choosing words for flash cards.
    private var flashSource: WordFlashSource {
        switch filter {
        case .all: .all
        case .pinned: .pinned
        case .folder(let id): .folder(id)
        }
    }

    // MARK: Filter bar (All, Pinned, folders, +)

    private var filterBar: some View {
        FlowLayout(spacing: 8, lineSpacing: 8, centered: false) {
            chip("All words", count: history.entries.count, filter: .all)
            chip("📌 Pinned", count: history.entries.filter(\.isPinned).count, filter: .pinned)
            folderMenu
        }
    }

    private var selectedFolder: WordFolder? {
        if case .folder(let id) = filter { return history.folders.first { $0.id == id } }
        return nil
    }

    /// Folders in a drop-down: choose one, create one, or rename / delete the chosen one.
    private var folderMenu: some View {
        Menu {
            if !history.folders.isEmpty {
                Section("Folders") {
                    ForEach(history.folders) { folder in
                        Button {
                            filter = .folder(folder.id)
                        } label: {
                            if selectedFolder?.id == folder.id {
                                Label("\(folder.name) (\(history.count(in: folder)))", systemImage: "checkmark")
                            } else {
                                Text("\(folder.name) (\(history.count(in: folder)))")
                            }
                        }
                    }
                }
            }
            Button("New folder…", systemImage: "folder.badge.plus") { startNewFolder(for: []) }
            if let folder = selectedFolder {
                Section("“\(folder.name)”") {
                    Button("Rename…", systemImage: "pencil") { startRenaming(folder) }
                    Button("Delete folder…", systemImage: "trash", role: .destructive) { folderToDelete = folder }
                }
            }
        } label: {
            chipLabel(
                selectedFolder.map { "📁 \($0.name)" } ?? "📁 Folders",
                count: selectedFolder.map { history.count(in: $0) },
                isSelected: selectedFolder != nil,
                showsChevron: true
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .fixedSize()
    }

    private func chip(_ title: String, count: Int, filter chipFilter: Filter) -> some View {
        Button {
            filter = chipFilter
        } label: {
            chipLabel(title, count: count, isSelected: filter == chipFilter)
        }
        .buttonStyle(.plain)
    }

    private func chipLabel(_ title: String, count: Int?, isSelected: Bool, showsChevron: Bool = false) -> some View {
        HStack(spacing: 5) {
            Text(title)
            if let count {
                Text("\(count)").foregroundStyle(.secondary)
            }
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(isSelected ? Color.orange.opacity(0.25) : Color.secondary.opacity(0.1)))
        .overlay(Capsule().strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 2))
        .contentShape(Capsule())
    }

    // MARK: Select mode

    /// The words currently listed (search results or the chosen filter).
    private var visibleEntries: [HistoryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? filtered : history.entries.searched(query)
    }

    private func selectionBar(_ ids: Set<String>) -> some View {
        let selected = history.entries.filter { ids.contains($0.id) }
        let allPinned = !selected.isEmpty && selected.allSatisfy(\.isPinned)
        return HStack(spacing: 14) {
            Button("Cancel") { picking = nil }
            Spacer()
            Text(ids.count == 1 ? "1 selected" : "\(ids.count) selected")
                .font(.headline)
                .monospacedDigit()
            Spacer()
            Menu {
                Section("Move to folder") {
                    ForEach(history.folders) { folder in
                        Button("📁 \(folder.name)") {
                            history.move(ids, to: folder)
                            picking = nil
                        }
                    }
                    Button("New folder…", systemImage: "folder.badge.plus") { startNewFolder(for: ids) }
                    Button("No folder", systemImage: "folder.badge.minus") {
                        history.move(ids, to: nil)
                        picking = nil
                    }
                }
                Button(allPinned ? "Unpin" : "Pin", systemImage: allPinned ? "pin.slash" : "pin") {
                    history.setPinned(ids, !allPinned)
                    picking = nil
                }
                Button("Flash cards", systemImage: "rectangle.on.rectangle.angled") {
                    let title = ids.count == 1 ? "1 chosen word" : "\(ids.count) chosen words"
                    flashDeck = .words(title: title, words: selected.map { style($0.word) })
                }
                .disabled(kanji == nil)
                Divider()
                Button("Delete…", systemImage: "trash", role: .destructive) { confirmDeleteSelected = true }
            } label: {
                Label("Actions", systemImage: "folder")
                    .labelStyle(.titleAndIcon)
            }
            .menuStyle(.button)
            .buttonStyle(.borderedProminent)
            .disabled(ids.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: Word list

    private var filtered: [HistoryEntry] {
        switch filter {
        case .all: history.entries
        case .pinned: history.entries.filter(\.isPinned)
        case .folder(let id): history.entries.filter { $0.folderID == id }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            searchResults
        } else {
            browseList
        }
    }

    /// While searching, look through all her words (not only the selected folder).
    @ViewBuilder
    private var searchResults: some View {
        let results = history.entries.searched(searchText)
        if results.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxHeight: .infinity)
        } else {
            List {
                Section("\(results.count) found") {
                    ForEach(results) { row($0) }
                }
            }
        }
    }

    @ViewBuilder
    private var browseList: some View {
        let entries = filtered
        if entries.isEmpty {
            ContentUnavailableView(emptyTitle, systemImage: "book", description: Text(emptyDescription))
                .frame(maxHeight: .infinity)
        } else {
            let pinned = entries.filter(\.isPinned)
            let others = entries.filter { !$0.isPinned }
            List {
                if !pinned.isEmpty, filter != .pinned {
                    Section("📌 Pinned") {
                        ForEach(pinned) { row($0) }
                    }
                }
                let rest = filter == .pinned ? pinned : others
                if !rest.isEmpty {
                    Section(filter == .pinned ? "📌 Pinned" : "Words") {
                        ForEach(rest) { row($0) }
                    }
                }
            }
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .all: "No words yet"
        case .pinned: "No pinned words"
        case .folder: "This folder is empty"
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .all: "Words you look up will appear here."
        case .pinned: "Pin your favourite words to keep them at the top."
        case .folder: "Tap Select, tick words, then Actions → Move to folder. Or long-press a word."
        }
    }

    private func row(_ entry: HistoryEntry) -> some View {
        let word = style(entry.word)
        let isChecked = picking?.contains(entry.id) == true
        return Button {
            if picking != nil {
                if isChecked { picking?.remove(entry.id) } else { picking?.insert(entry.id) }
            } else {
                onSelect(entry.word)
            }
        } label: {
            HStack(spacing: 14) {
                if picking != nil {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isChecked ? Color.accentColor : .secondary)
                }
                Text(word.emoji.isEmpty ? "📝" : word.emoji)
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(word.japanese)
                            .font(.handwriting(size: 30))
                        if showRomaji, !word.displayRomaji.isEmpty {
                            Text(word.displayRomaji)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    HStack(spacing: 6) {
                        if !word.meaning.isEmpty {
                            Text(word.meaning)
                        }
                        if let folder = history.folders.first(where: { $0.id == entry.folderID }), filter != .folder(folder.id) {
                            Text("📁 \(folder.name)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.orange)
                }
                if entry.totalStars > 0 {
                    Text("⭐️ \(entry.totalStars)")
                        .font(.headline)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) { history.delete(entry) }
        }
        .swipeActions(edge: .leading) {
            Button(entry.isPinned ? "Unpin" : "Pin", systemImage: entry.isPinned ? "pin.slash" : "pin") {
                history.togglePin(entry)
            }
            .tint(.orange)
        }
        .contextMenu { if picking == nil { wordMenu(entry) } }
    }

    @ViewBuilder
    private func wordMenu(_ entry: HistoryEntry) -> some View {
        Button(entry.isPinned ? "Unpin" : "Pin", systemImage: entry.isPinned ? "pin.slash" : "pin") {
            history.togglePin(entry)
        }
        Menu("Move to folder", systemImage: "folder") {
            ForEach(history.folders) { folder in
                Button {
                    history.move(entry, to: folder)
                } label: {
                    if entry.folderID == folder.id {
                        Label(folder.name, systemImage: "checkmark")
                    } else {
                        Text(folder.name)
                    }
                }
            }
            if entry.folderID != nil {
                Button("No folder", systemImage: "folder.badge.minus") { history.move(entry, to: nil) }
            }
            Divider()
            Button("New folder…", systemImage: "folder.badge.plus") { startNewFolder(for: [entry.id]) }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { history.delete(entry) }
    }

    // MARK: Folder editing

    private func startNewFolder(for ids: Set<String>) {
        renamingFolder = nil
        entriesForNewFolder = ids
        folderName = ""
        showFolderNameAlert = true
    }

    private func startRenaming(_ folder: WordFolder) {
        renamingFolder = folder
        entriesForNewFolder = []
        folderName = folder.name
        showFolderNameAlert = true
    }

    private func commitFolderName() {
        if let folder = renamingFolder {
            history.rename(folder, to: folderName)
        } else if let folder = history.createFolder(named: folderName) {
            if entriesForNewFolder.isEmpty {
                filter = .folder(folder.id)
            } else {
                history.move(entriesForNewFolder, to: folder)
                picking = nil
            }
        }
        resetFolderEditing()
    }

    private func resetFolderEditing() {
        renamingFolder = nil
        entriesForNewFolder = []
        folderName = ""
    }
}
