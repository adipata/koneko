import SwiftUI

/// Spaced-repetition progress for every flash card she has reviewed, saved on this device.
/// Cards are remembered by `FlashCard.reviewKey(_:)`, so the same kana, kanji or word shares its
/// progress across all decks and sets.
@Observable
final class ReviewStore {
    private(set) var states: [String: ReviewState] = [:]
    /// Increases on every change.
    private(set) var revision = 0
    /// When progress was last reset: older answers from the watch are ignored.
    private(set) var resetAt: Date?
    private let fileURL: URL
    private static let resetKey = "reviewsResetAt"

    init() {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appending(path: "reviews.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([String: ReviewState].self, from: data) {
            states = saved
        }
        resetAt = UserDefaults.standard.object(forKey: Self.resetKey) as? Date
    }

    func state(for key: String) -> ReviewState? {
        states[key]
    }

    func record(_ rating: ReviewRating, for key: String, at now: Date = .now) {
        states[key] = FSRS.review(states[key], rating: rating, at: now)
        save()
    }

    /// How many of `keys` she met for the first time today.
    func introducedToday(_ keys: [String]) -> Int {
        states.introducedToday(keys)
    }

    /// Her garden for these cards: sprouts, growing and blooming plants, and seeds not met yet.
    func garden(_ keys: [String]) -> Garden {
        states.garden(keys)
    }

    /// Adds the answers she gave on the Apple Watch (see `[String: ReviewState].apply`).
    func add(_ answers: [WatchAnswer]) {
        if states.apply(answers, after: resetAt) { save() }
    }

    /// Forgets all review progress (Settings).
    func removeAll() {
        states = [:]
        resetAt = .now
        UserDefaults.standard.set(resetAt, forKey: Self.resetKey)
        save()
    }

    private func save() {
        revision += 1
        if let data = try? JSONEncoder().encode(states) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
