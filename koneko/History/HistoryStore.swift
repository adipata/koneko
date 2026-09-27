import SwiftUI
import UniformTypeIdentifiers

/// A word in her dictionary, with the best stars she earned per character in Practice.
nonisolated struct HistoryEntry: Codable, Identifiable, Sendable {
    var word: WordCandidate
    var lastUsed: Date
    var timesUsed: Int
    /// Best stars (1–3) per practiced character.
    var stars: [String: Int]
    var isPinned = false
    /// The folder (category) it's in, if any.
    var folderID: UUID?

    var id: String { word.id }
    var totalStars: Int { stars.values.reduce(0, +) }

    init(word: WordCandidate, lastUsed: Date = .now, timesUsed: Int = 1, stars: [String: Int] = [:]) {
        self.word = word
        self.lastUsed = lastUsed
        self.timesUsed = timesUsed
        self.stars = stars
    }

    // Tolerant decoding: files saved before pins and folders existed don't have those fields.
    private enum CodingKeys: String, CodingKey {
        case word, lastUsed, timesUsed, stars, isPinned, folderID
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decode(WordCandidate.self, forKey: .word)
        lastUsed = try container.decodeIfPresent(Date.self, forKey: .lastUsed) ?? .now
        timesUsed = try container.decodeIfPresent(Int.self, forKey: .timesUsed) ?? 1
        stars = try container.decodeIfPresent([String: Int].self, forKey: .stars) ?? [:]
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
    }
}

/// A category she creates, e.g. "🐾 Animals".
nonisolated struct WordFolder: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
}

/// Everything in her dictionary; also the format of exported files.
nonisolated struct DictionaryFile: Codable, Sendable {
    var app = "Koneko"
    var version = 1
    var exportedAt = Date.now
    var folders: [WordFolder]
    var entries: [HistoryEntry]

    static func decode(_ data: Data) throws -> DictionaryFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let file = try? decoder.decode(DictionaryFile.self, from: data) {
            return file
        }
        // Older format: just a list of words.
        if let entries = try? decoder.decode([HistoryEntry].self, from: data) {
            return DictionaryFile(folders: [], entries: entries)
        }
        // Files saved by earlier app versions used the default date format.
        if let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            return DictionaryFile(folders: [], entries: entries)
        }
        throw CocoaError(.fileReadCorruptFile)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

/// Her word list ("My words"), saved on the device.
@Observable
final class HistoryStore {
    private(set) var entries: [HistoryEntry] = []
    private(set) var folders: [WordFolder] = []
    private let fileURL: URL

    init() {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appending(path: "history.json")
        if let data = try? Data(contentsOf: fileURL), let file = try? DictionaryFile.decode(data) {
            entries = file.entries
            folders = file.folders
        }
    }

    // MARK: Words

    func record(_ word: WordCandidate) {
        if let index = entries.firstIndex(where: { $0.id == word.id }) {
            var entry = entries.remove(at: index)
            entry.lastUsed = .now
            entry.timesUsed += 1
            entries.insert(entry, at: 0)
        } else {
            entries.insert(HistoryEntry(word: word), at: 0)
        }
        save()
    }

    func recordStars(_ stars: Int, for character: Character, in word: WordCandidate) {
        update(word.id) { entry in
            let key = String(character)
            entry.stars[key] = max(entry.stars[key] ?? 0, stars)
        }
    }

    func togglePin(_ entry: HistoryEntry) {
        update(entry.id) { $0.isPinned.toggle() }
    }

    func move(_ entry: HistoryEntry, to folder: WordFolder?) {
        update(entry.id) { $0.folderID = folder?.id }
    }

    func delete(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func removeAll() {
        entries = []
        folders = []
        save()
    }

    // MARK: Folders

    @discardableResult
    func createFolder(named name: String) -> WordFolder? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        if let existing = folders.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let folder = WordFolder(name: name)
        folders.append(folder)
        save()
        return folder
    }

    func rename(_ folder: WordFolder, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[index].name = name
        save()
    }

    /// Deletes the folder; its words stay in "All words".
    func delete(_ folder: WordFolder) {
        folders.removeAll { $0.id == folder.id }
        for index in entries.indices where entries[index].folderID == folder.id {
            entries[index].folderID = nil
        }
        save()
    }

    func count(in folder: WordFolder) -> Int {
        entries.filter { $0.folderID == folder.id }.count
    }

    // MARK: Export / import

    func exportData() throws -> Data {
        try DictionaryFile(folders: folders, entries: entries).encoded()
    }

    /// Imports a dictionary file. Returns how many new words were added.
    @discardableResult
    func importData(_ data: Data, replacing: Bool) throws -> Int {
        let file = try DictionaryFile.decode(data)
        if replacing {
            folders = file.folders
            entries = file.entries.sorted { $0.lastUsed > $1.lastUsed }
            save()
            return entries.count
        }

        // Merge folders by name, so importing the same file twice doesn't duplicate them.
        var folderMap: [UUID: UUID] = [:]
        for folder in file.folders {
            if let existing = folders.first(where: { $0.id == folder.id || $0.name.localizedCaseInsensitiveCompare(folder.name) == .orderedSame }) {
                folderMap[folder.id] = existing.id
            } else {
                folders.append(folder)
                folderMap[folder.id] = folder.id
            }
        }

        var added = 0
        for var imported in file.entries {
            imported.folderID = imported.folderID.flatMap { folderMap[$0] }
            if let index = entries.firstIndex(where: { $0.id == imported.id }) {
                var entry = entries[index]
                entry.stars.merge(imported.stars) { max($0, $1) }
                entry.isPinned = entry.isPinned || imported.isPinned
                entry.folderID = entry.folderID ?? imported.folderID
                entry.timesUsed = max(entry.timesUsed, imported.timesUsed)
                entry.lastUsed = max(entry.lastUsed, imported.lastUsed)
                entries[index] = entry
            } else {
                entries.append(imported)
                added += 1
            }
        }
        entries.sort { $0.lastUsed > $1.lastUsed }
        save()
        return added
    }

    // MARK: Private

    private func update(_ id: String, _ change: (inout HistoryEntry) -> Void) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        change(&entries[index])
        save()
    }

    private func save() {
        if let data = try? DictionaryFile(folders: folders, entries: entries).encoded() {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

/// Wraps an exported dictionary for the system "Save" dialog.
nonisolated struct DictionaryDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
