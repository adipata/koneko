import Foundation

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
