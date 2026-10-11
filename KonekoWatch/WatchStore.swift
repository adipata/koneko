import Foundation
import Observation

/// The word list on the watch: read from iCloud (published by the iPhone/iPad/Mac app)
/// and cached on the watch so it also works offline.
@Observable
final class WatchStore {
    private(set) var snapshot: WatchSnapshot?
    /// Review progress from the iPhone/iPad/Mac (nil until one has shared it).
    private(set) var reviews: WatchReviews?
    /// Answers given on the watch that aren't in `reviews` yet. Kept on the watch, so she can
    /// review offline; they go to iCloud and the phone adds them to her progress.
    private(set) var answers: [WatchAnswer] = []
    private let cacheURL: URL
    private let reviewsCacheURL: URL
    private let answersURL: URL

    init() {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        cacheURL = folder.appending(path: "watchSnapshot.lzfse")
        reviewsCacheURL = folder.appending(path: "watchReviews.lzfse")
        answersURL = folder.appending(path: "watchAnswers.json")
        if let cached = try? Data(contentsOf: cacheURL) {
            snapshot = CloudSync.decode(cached)
        }
        if let cached = try? Data(contentsOf: reviewsCacheURL) {
            reviews = CloudSync.decode(WatchReviews.self, from: cached)
        }
        if let data = try? Data(contentsOf: answersURL),
           let saved = try? JSONDecoder().decode([WatchAnswer].self, from: data) {
            answers = saved
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

    /// Reads the latest word list and review progress from iCloud's local copy.
    func reload() {
        let store = NSUbiquitousKeyValueStore.default
        if let compressed = store.data(forKey: CloudSync.reviewsKey),
           let latest = CloudSync.decode(WatchReviews.self, from: compressed) {
            reviews = latest
            try? compressed.write(to: reviewsCacheURL, options: .atomic)
            dropReceivedAnswers()
        }
        guard let compressed = store.data(forKey: CloudSync.key),
              let latest = CloudSync.decode(compressed)
        else { return }
        snapshot = latest
        try? compressed.write(to: cacheURL, options: .atomic)
    }

    // MARK: Review

    /// Review is offered when the iPhone/iPad/Mac shares progress and has Review mode on.
    var canReview: Bool { reviews?.reviewMode ?? false }

    var newCardsPerDay: Int { reviews?.newCardsPerDay ?? 0 }

    /// Her progress as the phone last sent it, plus the answers it doesn't have yet.
    var reviewStates: [String: ReviewState] {
        var states = reviews?.states ?? [:]
        states.apply(answers, after: reviews?.resetAt)
        return states
    }

    func record(_ rating: ReviewRating, for key: String) {
        answers.append(WatchAnswer(key: key, rating: rating, date: .now))
        saveAnswers()
    }

    /// Forgets the answers the phone's progress already has (or that a reset forgot).
    private func dropReceivedAnswers() {
        guard let reviews else { return }
        let waiting = answers.filter { answer in
            if let reset = reviews.resetAt, answer.date <= reset { return false }
            guard let state = reviews.states[answer.key] else { return true }
            return state.lastReview < answer.date
        }
        if waiting != answers {
            answers = waiting
            saveAnswers()
        }
    }

    private func saveAnswers() {
        if let data = try? JSONEncoder().encode(answers) {
            try? data.write(to: answersURL, options: .atomic)
        }
        try? CloudSync.save(answers, forKey: CloudSync.answersKey)
    }

    private(set) var isRefreshing = false

    /// Asks iCloud for news, then reloads. iCloud may deliver the update a moment later
    /// (it then also arrives through the change notification), so look again after a pause.
    func refresh() async {
        isRefreshing = true
        NSUbiquitousKeyValueStore.default.synchronize()
        reload()
        try? await Task.sleep(for: .seconds(2))
        reload()
        isRefreshing = false
    }
}
