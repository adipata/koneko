import SwiftUI

/// Publishes "My words" (and how words are written) to iCloud for the Apple Watch app.
@Observable
final class WatchSyncController {
    private(set) var status: String?
    private(set) var isError = false

    /// Call whenever the words or the writing settings change.
    func update(history: HistoryStore, settings: AppSettings) {
        guard settings.syncToWatch else { return }
        let snapshot = WatchSnapshot(
            dictionary: DictionaryFile(folders: history.folders, entries: history.entries),
            writingStyle: settings.writingStyle.rawValue,
            kanjiLevel: settings.kanjiLevel,
            showRomaji: settings.showRomaji,
            showFurigana: settings.showFurigana
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

    func stopSharing() {
        CloudSync.remove()
        status = nil
        isError = false
    }
}
