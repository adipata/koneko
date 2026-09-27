import Foundation
import Observation

/// The word list on the watch: read from iCloud (published by the iPhone/iPad/Mac app)
/// and cached on the watch so it also works offline.
@Observable
final class WatchStore {
    private(set) var snapshot: WatchSnapshot?
    private let cacheURL: URL

    init() {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        cacheURL = folder.appending(path: "watchSnapshot.lzfse")
        if let cached = try? Data(contentsOf: cacheURL) {
            snapshot = CloudSync.decode(cached)
        }
        reload()
    }

    var entries: [HistoryEntry] { snapshot?.dictionary.entries ?? [] }
    var folders: [WordFolder] { snapshot?.dictionary.folders ?? [] }
    var pinned: [HistoryEntry] { entries.filter(\.isPinned) }

    func entries(in folder: WordFolder) -> [HistoryEntry] {
        entries.filter { $0.folderID == folder.id }
    }

    /// The word as it should appear, using the writing settings from the iPad.
    func display(_ word: WordCandidate) -> WordCandidate {
        snapshot?.display(word) ?? word
    }

    /// Reads the latest word list from iCloud's local copy.
    func reload() {
        guard let compressed = NSUbiquitousKeyValueStore.default.data(forKey: CloudSync.key),
              let latest = CloudSync.decode(compressed)
        else { return }
        if let current = snapshot, current.updatedAt > latest.updatedAt { return }
        snapshot = latest
        try? compressed.write(to: cacheURL, options: .atomic)
    }

    /// Asks iCloud for news, then reloads.
    func refresh() {
        NSUbiquitousKeyValueStore.default.synchronize()
        reload()
    }
}
