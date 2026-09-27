import Foundation

/// What the iPhone/iPad/Mac app shares with the Apple Watch app through iCloud.
nonisolated struct WatchSnapshot: Codable, Sendable {
    var dictionary: DictionaryFile
    var writingStyle: String
    var kanjiLevel: Int
    var showRomaji: Bool
    var showFurigana: Bool
    var updatedAt = Date.now

    var style: WritingStyle { WritingStyle(rawValue: writingStyle) ?? .natural }

    func display(_ word: WordCandidate) -> WordCandidate {
        style.apply(to: word, kanjiLevel: kanjiLevel)
    }
}

/// Stores the word list in iCloud key-value storage, where the watch app reads it.
///
/// Both apps need the iCloud "Key-value storage" capability with the same key-value store
/// identifier (the iPhone app's). The data is compressed; the store allows 1 MB per key,
/// which is room for a few thousand words.
nonisolated enum CloudSync {
    static let key = "koneko.watchSnapshot.v1"
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

    /// Stops sharing: removes the word list from iCloud.
    static func remove() {
        NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}
