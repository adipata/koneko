import Foundation

/// What she is reading: it changes how the AI reads a picture (a manga panel gets a short
/// description of the scene, kept as hidden context).
nonisolated enum ReadingKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case book
    case manga

    var id: String { rawValue }

    var name: String {
        switch self {
        case .book: "Book"
        case .manga: "Manga"
        }
    }

    var emoji: String {
        switch self {
        case .book: "📖"
        case .manga: "🗯️"
        }
    }
}

/// How a part was given to the AI.
nonisolated enum ReadingSource: String, Codable, Sendable {
    /// Text selected in the photo with Live Text (only the text is sent).
    case text
    /// A cropped part of the photo (the picture is sent).
    case picture
}

/// The AI's explanation of one part, saved for review. It is never sent back to the AI.
nonisolated struct ReadingExplanation: Codable, Hashable, Sendable {
    nonisolated struct Word: Codable, Hashable, Sendable {
        var japanese: String
        var reading: String
        var meaning: String
        var note: String
    }

    nonisolated struct Kanji: Codable, Hashable, Sendable {
        var kanji: String
        var reading: String
        var meaning: String
        var note: String
    }

    /// A natural English translation.
    var translation: String
    /// The whole text in kana only.
    var kana: String
    /// How the text is built: word order, particles, verb forms, other meanings.
    var explanation: String
    var words: [Word]
    var kanji: [Kanji]

    /// Nothing to show (the AI's answer came back empty).
    var isEmpty: Bool {
        translation.isEmpty && kana.isEmpty && explanation.isEmpty && words.isEmpty && kanji.isEmpty
    }
}

/// One scanned word or phrase of a reading.
nonisolated struct ReadingEntry: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var date = Date.now
    /// The Japanese text (what she sees in the history and can copy).
    var text: String
    var source: ReadingSource
    /// Hidden context for the next parts: what a manga panel shows. Empty for books and text.
    var scene: String
    var explanation: ReadingExplanation
}

/// A book or manga she is reading, with the history of the parts she scanned (oldest first).
nonisolated struct Reading: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var kind: ReadingKind
    var created = Date.now
    var updated = Date.now
    var entries: [ReadingEntry] = []
}

/// Her readings ("Reading" section), saved on the device.
@Observable
final class ReadingStore {
    /// Most recently read first.
    private(set) var readings: [Reading] = []
    private let fileURL: URL

    init() {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appending(path: "readings.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? decoder.decode([Reading].self, from: data) {
            readings = saved.sorted { $0.updated > $1.updated }
        }
    }

    func reading(_ id: Reading.ID) -> Reading? {
        readings.first { $0.id == id }
    }

    @discardableResult
    func create(title: String, kind: ReadingKind) -> Reading {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let reading = Reading(title: trimmed.isEmpty ? "My \(kind.name.lowercased())" : trimmed, kind: kind)
        readings.insert(reading, at: 0)
        save()
        return reading
    }

    func rename(_ id: Reading.ID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(id) { $0.title = trimmed }
    }

    func delete(_ id: Reading.ID) {
        readings.removeAll { $0.id == id }
        save()
    }

    func add(_ entry: ReadingEntry, to id: Reading.ID) {
        update(id) { reading in
            reading.entries.append(entry)
            reading.updated = .now
        }
        // The reading just used goes to the top.
        if let index = readings.firstIndex(where: { $0.id == id }), index > 0 {
            readings.insert(readings.remove(at: index), at: 0)
            save()
        }
    }

    func setExplanation(_ explanation: ReadingExplanation, of entryID: ReadingEntry.ID, in id: Reading.ID) {
        update(id) { reading in
            guard let index = reading.entries.firstIndex(where: { $0.id == entryID }) else { return }
            reading.entries[index].explanation = explanation
        }
    }

    func deleteEntry(_ entryID: ReadingEntry.ID, from id: Reading.ID) {
        update(id) { $0.entries.removeAll { $0.id == entryID } }
    }

    private func update(_ id: Reading.ID, _ change: (inout Reading) -> Void) {
        guard let index = readings.firstIndex(where: { $0.id == id }) else { return }
        change(&readings[index])
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(readings) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
