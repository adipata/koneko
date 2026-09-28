import SwiftUI

/// "My words": her dictionary, with pinned words and folders (categories).
struct HistoryView: View {
    let history: HistoryStore
    let style: (WordCandidate) -> WordCandidate
    let onSelect: (WordCandidate) -> Void
    var showRomaji = true

    private enum Filter: Hashable {
        case all
        case pinned
        case folder(UUID)
    }

    @State private var filter = Filter.all
    @State private var searchText = ""

    // Folder create / rename
    @State private var showFolderNameAlert = false
    @State private var folderName = ""
    @State private var renamingFolder: WordFolder?
    /// Word to put into the folder that's being created.
    @State private var entryForNewFolder: HistoryEntry?
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

    // MARK: Filter bar (All, Pinned, folders, +)

    private var filterBar: some View {
        FlowLayout(spacing: 8, lineSpacing: 8, centered: false) {
            chip("All words", count: history.entries.count, filter: .all)
            chip("📌 Pinned", count: history.entries.filter(\.isPinned).count, filter: .pinned)
            ForEach(history.folders) { folder in
                chip("📁 \(folder.name)", count: history.count(in: folder), filter: .folder(folder.id))
                    .contextMenu {
                        Button("Rename", systemImage: "pencil") { startRenaming(folder) }
                        Button("Delete folder", systemImage: "trash", role: .destructive) { folderToDelete = folder }
                    }
            }
            Button("New folder", systemImage: "folder.badge.plus") { startNewFolder(for: nil) }
                .buttonStyle(.bordered)
        }
    }

    private func chip(_ title: String, count: Int, filter chipFilter: Filter) -> some View {
        let isSelected = filter == chipFilter
        return Button {
            filter = chipFilter
        } label: {
            Text("\(title) \(Text("\(count)").foregroundStyle(.secondary))")
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(isSelected ? Color.orange.opacity(0.25) : Color.secondary.opacity(0.1)))
                .overlay(Capsule().strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
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
        case .folder: "Long-press (or right-click) a word and choose “Move to folder”."
        }
    }

    private func row(_ entry: HistoryEntry) -> some View {
        let word = style(entry.word)
        return Button {
            onSelect(entry.word)
        } label: {
            HStack(spacing: 14) {
                Text(word.emoji.isEmpty ? "📝" : word.emoji)
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(word.japanese)
                            .font(.handwriting(size: 30))
                        if showRomaji, !word.displayRomaji.isEmpty {
                            Text(word.displayRomaji)
                                .font(.system(.title3, design: .rounded).weight(.medium))
                                .foregroundStyle(.orange)
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
        .contextMenu { wordMenu(entry) }
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
            Button("New folder…", systemImage: "folder.badge.plus") { startNewFolder(for: entry) }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { history.delete(entry) }
    }

    // MARK: Folder editing

    private func startNewFolder(for entry: HistoryEntry?) {
        renamingFolder = nil
        entryForNewFolder = entry
        folderName = ""
        showFolderNameAlert = true
    }

    private func startRenaming(_ folder: WordFolder) {
        renamingFolder = folder
        entryForNewFolder = nil
        folderName = folder.name
        showFolderNameAlert = true
    }

    private func commitFolderName() {
        if let folder = renamingFolder {
            history.rename(folder, to: folderName)
        } else if let folder = history.createFolder(named: folderName) {
            if let entry = entryForNewFolder {
                history.move(entry, to: folder)
            } else {
                filter = .folder(folder.id)
            }
        }
        resetFolderEditing()
    }

    private func resetFolderEditing() {
        renamingFolder = nil
        entryForNewFolder = nil
        folderName = ""
    }
}
