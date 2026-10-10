import SwiftUI

/// Spaced-repetition progress for every flash card she has reviewed, saved on this device.
/// Cards are remembered by `FlashCard.reviewKey(_:)`, so the same kana, kanji or word shares its
/// progress across all decks and sets.
@Observable
final class ReviewStore {
    private(set) var states: [String: ReviewState] = [:]
    /// Increases on every change.
    private(set) var revision = 0
    private let fileURL: URL

    init() {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appending(path: "reviews.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([String: ReviewState].self, from: data) {
            states = saved
        }
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
        let calendar = Calendar.current
        return keys.filter { key in
            states[key].map { calendar.isDateInToday($0.introduced) } ?? false
        }.count
    }

    /// Her garden for these cards: sprouts, growing and blooming plants, and seeds not met yet.
    func garden(_ keys: [String]) -> Garden {
        var garden = Garden()
        for key in Set(keys) {
            if let state = states[key] {
                garden.counts[state.stage, default: 0] += 1
            } else {
                garden.seeds += 1
            }
        }
        return garden
    }

    /// Forgets all review progress (Settings).
    func removeAll() {
        states = [:]
        save()
    }

    private func save() {
        revision += 1
        if let data = try? JSONEncoder().encode(states) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
