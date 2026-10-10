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
    /// What she typed or said to find it (e.g. "kitty"), so searching for that finds it too.
    var lookedUpAs: [String] = []

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
        case word, lastUsed, timesUsed, stars, isPinned, folderID, lookedUpAs
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decode(WordCandidate.self, forKey: .word)
        lastUsed = try container.decodeIfPresent(Date.self, forKey: .lastUsed) ?? .now
        timesUsed = try container.decodeIfPresent(Int.self, forKey: .timesUsed) ?? 1
        stars = try container.decodeIfPresent([String: Int].self, forKey: .stars) ?? [:]
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
        lookedUpAs = try container.decodeIfPresent([String].self, forKey: .lookedUpAs) ?? []
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

extension HistoryEntry {
    /// Search in English (meaning and what she typed), plus romaji and the Japanese itself.
    /// Ignores case and accents: "koko" finds "kōkō".
    nonisolated func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let fields = [word.meaning, word.romaji, word.japanese, word.reading] + lookedUpAs
        return fields.contains { $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil }
    }
}

extension [HistoryEntry] {
    /// Entries matching the search, best matches first (meaning starting with the query first).
    nonisolated func searched(_ query: String) -> [HistoryEntry] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return self }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .anchored]
        let startsWith = filter { entry in
            ([entry.word.meaning] + entry.lookedUpAs).contains { $0.range(of: query, options: options) != nil }
        }
        let others = filter { entry in entry.matches(query) && !startsWith.contains { $0.id == entry.id } }
        return startsWith + others
    }
}
