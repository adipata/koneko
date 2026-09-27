#if os(watchOS)
// Watch app only. If this folder is accidentally added to the iPhone/iPad/Mac target,
// this file compiles to nothing instead of breaking the build.
import Combine
import SwiftUI

/// Main screen: pinned words, folders and all words.
struct WatchWordListView: View {
    let store: WatchStore

    var body: some View {
        NavigationStack {
            Group {
                if store.entries.isEmpty {
                    emptyState
                } else {
                    List {
                        if !store.pinned.isEmpty {
                            Section("📌 Pinned") {
                                rows(store.pinned)
                            }
                        }
                        if !store.folders.isEmpty {
                            Section("Folders") {
                                ForEach(store.folders) { folder in
                                    NavigationLink {
                                        WatchFolderView(store: store, folder: folder)
                                    } label: {
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
                }
            }
            .navigationTitle("Koneko")
            .navigationDestination(for: WatchWordPage.self) { page in
                WatchWordPager(store: store, entries: page.entries, selection: page.startID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
            store.reload()
        }
        .task { store.refresh() }
    }

    @ViewBuilder
    private func rows(_ entries: [HistoryEntry]) -> some View {
        ForEach(entries) { entry in
            NavigationLink(value: WatchWordPage(entries: entries, startID: entry.id)) {
                WatchWordRow(word: store.display(entry.word))
            }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("🐱").font(.system(size: 44))
                Text("No words yet")
                    .font(.headline)
                Text("On the iPhone, iPad or Mac, open Koneko → Settings → Apple Watch and turn on “Sync My words”.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Refresh", systemImage: "arrow.clockwise") { store.refresh() }
            }
            .padding(.horizontal, 4)
        }
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
                NavigationLink(value: WatchWordPage(entries: entries, startID: entry.id)) {
                    WatchWordRow(word: store.display(entry.word))
                }
            }
        }
        .navigationTitle(folder.name)
    }
}

struct WatchWordRow: View {
    let word: WordCandidate

    var body: some View {
        HStack(spacing: 8) {
            Text(word.emoji.isEmpty ? "📝" : word.emoji)
                .font(.title3)
            VStack(alignment: .leading, spacing: 0) {
                Text(word.japanese)
                    .font(.handwriting(size: 22))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
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
#endif
