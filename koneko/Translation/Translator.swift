import SwiftUI

/// Looks up Japanese words: from the on-device cache when possible, otherwise via OpenRouter.
@Observable
final class Translator {
    enum Status: Equatable {
        case idle
        case loading
        case results([WordCandidate])
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var cachedWordCount = 0
    private let cache = TranslationCache()
    private var currentTask: Task<Void, Never>?

    init() {
        cachedWordCount = cache.count
    }

    func translate(_ text: String, language: InputLanguage, settings: AppSettings) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        currentTask?.cancel()

        if let cached = cache.candidates(for: query, language: language) {
            status = .results(cached)
            return
        }
        guard let apiKey = Keychain.apiKey, !apiKey.isEmpty else {
            status = .failed(TranslationError.missingAPIKey.localizedDescription)
            return
        }

        status = .loading
        let client = OpenRouterClient(apiKey: apiKey, model: settings.model)
        currentTask = Task {
            do {
                let candidates = try await client.translate(query, language: language)
                guard !Task.isCancelled else { return }
                if !candidates.isEmpty {
                    cache.store(candidates, for: query, language: language)
                    cachedWordCount = cache.count
                }
                status = .results(candidates)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                status = .failed(error.localizedDescription)
            }
        }
    }

    func reset() {
        currentTask?.cancel()
        status = .idle
    }

    func clearCache() {
        cache.removeAll()
        cachedWordCount = 0
    }
}

/// Remembers every lookup on the device, so repeats are instant and work offline.
final class TranslationCache {
    private var entries: [String: [WordCandidate]] = [:]
    private let fileURL: URL

    init() {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appending(path: "translations.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([String: [WordCandidate]].self, from: data) {
            entries = saved
        }
    }

    var count: Int { entries.count }

    func candidates(for text: String, language: InputLanguage) -> [WordCandidate]? {
        entries[Self.key(text, language)]
    }

    func store(_ candidates: [WordCandidate], for text: String, language: InputLanguage) {
        entries[Self.key(text, language)] = candidates
        save()
    }

    func removeAll() {
        entries = [:]
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private static func key(_ text: String, _ language: InputLanguage) -> String {
        let normalized = text.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return "\(language.rawValue):\(normalized)"
    }
}
