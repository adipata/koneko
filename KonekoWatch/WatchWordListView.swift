import Combine
import SwiftUI

/// Main screen: kana charts, pinned words, folders and all words.
struct WatchWordListView: View {
    let store: WatchStore
    let kanji: KanjiLibrary
    @Environment(\.scenePhase) private var scenePhase
    @State private var searchText = ""
    /// All navigation goes through this path (value-based links only), so pushed screens stay
    /// put when the list refreshes.
    @State private var path: [WatchRoute] = []

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                List {
                    if !isSearching {
                        Section("Learn") {
                            ForEach(KanaScript.allCases) { script in
                                NavigationLink(value: WatchRoute.kanaList(script)) {
                                    HStack(spacing: 10) {
                                        Text(script.text("あ"))
                                            .font(.title2)
                                        Text(script.title)
                                    }
                                }
                            }
                            NavigationLink(value: WatchRoute.flashMenu) {
                                HStack(spacing: 10) {
                                    Text("🃏")
                                        .font(.title2)
                                    Text("Flash cards")
                                }
                            }
                        }
                    }
                    if store.entries.isEmpty {
                        Section("My words") {
                            emptyState
                        }
                    } else if isSearching {
                        let results = store.entries.searched(searchText)
                        Section(results.isEmpty ? "Nothing found" : "\(results.count) found") {
                            rows(results)
                        }
                    } else {
                        if !store.pinned.isEmpty {
                            Section("📌 Pinned") {
                                rows(store.pinned)
                            }
                        }
                        if !store.folders.isEmpty {
                            Section("Folders") {
                                ForEach(store.folders) { folder in
                                    NavigationLink(value: WatchRoute.folder(folder.id)) {
                                        HStack {
                                            Text("📁 \(folder.name)")
                                            Spacer()
                                            Text("\(store.entries(in: folder).count)")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        Section("All words") {
                            rows(store.entries)
                        }
                    }
                    Section {
                        refreshButton
                    } footer: {
                        if let snapshot = store.snapshot {
                            Text("Updated \(snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))\(snapshot.source.map { " from \($0)" } ?? "")")
                        }
                    }
                }
                .refreshable { await store.refresh() }
                .searchable(text: $searchText, prompt: "Search in English")
            }
            .navigationTitle("Koneko")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await store.refresh() }
                    }
                    .disabled(store.isRefreshing)
                }
            }
            .navigationDestination(for: WatchRoute.self) { route in
                switch route {
                case .kanaList(let script):
                    WatchKanaListView(script: script)
                case .kana(let page):
                    WatchKanaPager(script: page.script, selection: page.startID)
                case .folder(let id):
                    if let folder = store.folders.first(where: { $0.id == id }) {
                        WatchFolderView(store: store, folder: folder)
                    }
                case .words(let page):
                    WatchWordPager(store: store, entries: page.entries, selection: page.startID)
                case .flashMenu:
                    WatchFlashMenuView()
                case .flash(let deck):
                    WatchFlashSessionView(deck: deck, kanji: kanji)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
            store.reload()
        }
        .task { await store.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh() } }
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await store.refresh() }
        } label: {
            if store.isRefreshing {
                ProgressView()
            } else {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .disabled(store.isRefreshing)
    }

    @ViewBuilder
    private func rows(_ entries: [HistoryEntry]) -> some View {
        ForEach(entries) { entry in
            NavigationLink(value: WatchRoute.words(WatchWordPage(entries: entries, startID: entry.id))) {
                WatchWordRow(word: store.display(entry.word), showRomaji: store.snapshot.map { $0.showRomajiInLists ?? $0.showRomaji } ?? true)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("🐱 No words yet")
                .font(.headline)
            Text("On the iPhone, iPad or Mac, open Koneko → Settings → Apple Watch and turn on “Sync My words”.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// Words of one folder.
struct WatchFolderView: View {
    let store: WatchStore
    let folder: WordFolder

    var body: some View {
        let entries = store.entries(in: folder)
        List {
            if entries.isEmpty {
                Text("This folder is empty.")
                    .foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                NavigationLink(value: WatchRoute.words(WatchWordPage(entries: entries, startID: entry.id))) {
                    WatchWordRow(word: store.display(entry.word), showRomaji: store.snapshot.map { $0.showRomajiInLists ?? $0.showRomaji } ?? true)
                }
            }
        }
        .navigationTitle(folder.name)
    }
}

struct WatchWordRow: View {
    let word: WordCandidate
    var showRomaji = true

    var body: some View {
        HStack(spacing: 8) {
            Text(word.emoji.isEmpty ? "📝" : word.emoji)
                .font(.title3)
            VStack(alignment: .leading, spacing: 0) {
                Text(word.japanese)
                    .font(.handwriting(size: 22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if showRomaji, !word.displayRomaji.isEmpty {
                    Text(word.displayRomaji)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !word.meaning.isEmpty {
                    Text(word.meaning)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

/// Navigation value: a list of words and the one to open first.
struct WatchWordPage: Hashable {
    let entries: [HistoryEntry]
    let startID: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.startID == rhs.startID && lhs.entries.map(\.id) == rhs.entries.map(\.id)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(startID)
        hasher.combine(entries.map(\.id))
    }
}
