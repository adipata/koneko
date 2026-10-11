import Foundation

/// What the iPhone/iPad/Mac app shares with the Apple Watch app through iCloud.
nonisolated struct WatchSnapshot: Codable, Sendable {
    var dictionary: DictionaryFile
    var writingStyle: String
    var kanjiLevel: Int
    var showRomaji: Bool
    /// Romaji in the word list (nil in lists synced by older versions: then like showRomaji).
    var showRomajiInLists: Bool?
    var showFurigana: Bool
    /// Her flash-card sets (nil in lists synced by older versions).
    var flashSets: [FlashSet]?
    var updatedAt = Date.now
    /// Which device published it ("iPhone", "iPad", "Mac"), shown on the watch.
    var source: String?

    var style: WritingStyle { WritingStyle(rawValue: writingStyle) ?? .natural }

    func display(_ word: WordCandidate) -> WordCandidate {
        style.apply(to: word, kanjiLevel: kanjiLevel)
    }
}

/// Her flash-card review progress, shared by the iPhone/iPad/Mac with the watch so she can
/// review there too. Kept apart from `WatchSnapshot` because it changes with every answer.
nonisolated struct WatchReviews: Codable, Sendable {
    var states: [String: ReviewState]
    /// Settings → Flash cards → Review mode.
    var reviewMode: Bool
    var newCardsPerDay: Int
    /// "Reset review progress": watch answers from before this are forgotten.
    var resetAt: Date?
    var updatedAt = Date.now
}

/// Stores the word list in iCloud key-value storage, where the watch app reads it.
///
/// Both apps need the iCloud "Key-value storage" capability with the same key-value store
/// identifier (the iPhone app's). The data is compressed; the store allows 1 MB per key,
/// which is room for a few thousand words.
nonisolated enum CloudSync {
    static let key = "koneko.watchSnapshot.v1"
    /// `WatchReviews`, written by the iPhone/iPad/Mac.
    static let reviewsKey = "koneko.watchReviews.v1"
    /// `[WatchAnswer]` not yet added to her progress, written by the watch.
    static let answersKey = "koneko.watchAnswers.v1"
    static let maxBytes = 1_000_000

    enum SyncError: LocalizedError {
        case notSignedIn
        case tooLarge(Int)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                "Not signed in to iCloud on this device."
            case .tooLarge(let bytes):
                "The word list is too big for iCloud sync (\(bytes / 1024) KB of 976 KB)."
            }
        }
    }

    static var isSignedIn: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Saves the snapshot to iCloud. Returns the compressed size in bytes.
    @discardableResult
    static func publish(_ snapshot: WatchSnapshot) throws -> Int {
        guard isSignedIn else { throw SyncError.notSignedIn }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(snapshot)
        let compressed = try (json as NSData).compressed(using: .lzfse) as Data
        guard compressed.count < maxBytes else { throw SyncError.tooLarge(compressed.count) }
        let store = NSUbiquitousKeyValueStore.default
        store.set(compressed, forKey: key)
        store.synchronize()
        return compressed.count
    }

    /// Reads the latest snapshot from iCloud (nil if there is none yet).
    static func read() -> WatchSnapshot? {
        guard let compressed = NSUbiquitousKeyValueStore.default.data(forKey: key) else { return nil }
        return decode(compressed)
    }

    static func decode(_ compressed: Data) -> WatchSnapshot? {
        guard let json = try? (compressed as NSData).decompressed(using: .lzfse) as Data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WatchSnapshot.self, from: json)
    }

    /// Saves review progress or watch answers (compressed JSON) under `key`. iCloud keeps it on
    /// the device until it can upload it.
    static func save<Value: Encodable>(_ value: Value, forKey key: String) throws {
        let json = try JSONEncoder().encode(value)
        let compressed = try (json as NSData).compressed(using: .lzfse) as Data
        guard compressed.count < maxBytes else { throw SyncError.tooLarge(compressed.count) }
        let store = NSUbiquitousKeyValueStore.default
        store.set(compressed, forKey: key)
        store.synchronize()
    }

    /// Reads what `save(_:forKey:)` wrote (nil if there is nothing yet).
    static func load<Value: Decodable>(_ type: Value.Type, forKey key: String) -> Value? {
        NSUbiquitousKeyValueStore.default.data(forKey: key).flatMap { decode(type, from: $0) }
    }

    static func decode<Value: Decodable>(_ type: Value.Type, from compressed: Data) -> Value? {
        guard let json = try? (compressed as NSData).decompressed(using: .lzfse) as Data else { return nil }
        return try? JSONDecoder().decode(type, from: json)
    }

    /// Stops sharing: removes the word list and review progress from iCloud.
    static func remove() {
        let store = NSUbiquitousKeyValueStore.default
        store.removeObject(forKey: key)
        store.removeObject(forKey: reviewsKey)
        store.synchronize()
    }
}
