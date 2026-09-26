import Foundation

/// A word she looked up, with the best stars she earned per character in Practice.
nonisolated struct HistoryEntry: Codable, Identifiable, Sendable {
    var word: WordCandidate
    var lastUsed: Date
    var timesUsed: Int
    /// Best stars (1–3) per practiced character.
    var stars: [String: Int]

    var id: String { word.id }
    var totalStars: Int { stars.values.reduce(0, +) }
}

/// Her word list, saved on the device.
@Observable
final class HistoryStore {
    private(set) var entries: [HistoryEntry] = []
    private let fileURL: URL

    init() {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appending(path: "history.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            entries = saved
        }
    }

    func record(_ word: WordCandidate) {
        if let index = entries.firstIndex(where: { $0.id == word.id }) {
            var entry = entries.remove(at: index)
            entry.lastUsed = .now
            entry.timesUsed += 1
            entries.insert(entry, at: 0)
        } else {
            entries.insert(HistoryEntry(word: word, lastUsed: .now, timesUsed: 1, stars: [:]), at: 0)
        }
        save()
    }

    func recordStars(_ stars: Int, for character: Character, in word: WordCandidate) {
        guard let index = entries.firstIndex(where: { $0.id == word.id }) else { return }
        let key = String(character)
        entries[index].stars[key] = max(entries[index].stars[key] ?? 0, stars)
        save()
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    func removeAll() {
        entries = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
