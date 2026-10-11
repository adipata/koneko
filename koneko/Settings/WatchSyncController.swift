import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Publishes "My words" (and how words are written) to iCloud for the Apple Watch app.
@Observable
final class WatchSyncController {
    private(set) var status: String?
    private(set) var isError = false

    /// Call whenever the words or the writing settings change.
    private var lastFlashSets: [FlashSet] = []

    /// `flashSets` nil = keep the ones sent last time (e.g. from the "Sync now" button).
    func update(history: HistoryStore, settings: AppSettings, flashSets: [FlashSet]? = nil) {
        let flashSets = flashSets ?? lastFlashSets
        lastFlashSets = flashSets
        guard settings.syncToWatch else { return }
        let snapshot = WatchSnapshot(
            dictionary: DictionaryFile(folders: history.folders, entries: history.entries),
            writingStyle: settings.writingStyle.rawValue,
            kanjiLevel: settings.kanjiLevel,
            showRomaji: settings.showRomaji,
            showRomajiInLists: settings.showRomajiInLists,
            showFurigana: settings.showFurigana,
            flashSets: flashSets,
            source: Self.deviceKind
        )
        do {
            let bytes = try CloudSync.publish(snapshot)
            let time = Date.now.formatted(date: .omitted, time: .shortened)
            status = "Synced \(history.entries.count) words at \(time) (\(max(1, bytes / 1024)) KB)."
            isError = false
        } catch {
            status = error.localizedDescription
            isError = true
        }
    }

    /// Shares her review progress so she can review on the watch. Call whenever it changes.
    func updateReviews(_ reviews: ReviewStore, settings: AppSettings) {
        guard settings.syncToWatch else { return }
        let shared = WatchReviews(
            states: reviews.states,
            reviewMode: settings.smartReview,
            newCardsPerDay: settings.newCardsPerDay,
            resetAt: reviews.resetAt
        )
        do {
            try CloudSync.save(shared, forKey: CloudSync.reviewsKey)
        } catch {
            status = error.localizedDescription
            isError = true
        }
    }

    /// Adds the answers she gave on the watch to her progress here. Safe to call often: answers
    /// already added are skipped. The watch drops them once the progress it gets back has them.
    func collectAnswers(into reviews: ReviewStore, settings: AppSettings) {
        guard settings.syncToWatch,
              let answers = CloudSync.load([WatchAnswer].self, forKey: CloudSync.answersKey),
              !answers.isEmpty
        else { return }
        reviews.add(answers)
    }

    private static var deviceKind: String {
        #if os(macOS)
        "Mac"
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #endif
    }

    func stopSharing() {
        CloudSync.remove()
        status = nil
        isError = false
    }
}
