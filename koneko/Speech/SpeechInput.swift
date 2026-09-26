import SwiftUI

/// Hold-to-talk state for the UI: start listening on press, get the words on release.
@Observable
final class SpeechInput {
    enum Status: Equatable {
        case idle
        case listening
        case finishing
    }

    struct Result {
        let text: String
        let alternatives: [String]
    }

    private(set) var status: Status = .idle
    /// Live transcript while she's speaking.
    private(set) var transcript = ""
    private(set) var level: Float = 0
    private(set) var errorMessage: String?

    private let engine = SpeechEngine()
    private var alternatives: [String] = []
    private var finalContinuation: CheckedContinuation<Void, Never>?
    private var receivedFinal = false
    private var hasPermission = false
    private var startTask: Task<Void, Never>?

    func start(language: InputLanguage) {
        guard status == .idle else { return }
        Pronouncer.shared.stop()
        errorMessage = nil
        transcript = ""
        alternatives = []
        receivedFinal = false
        status = .listening

        startTask = Task {
            if !hasPermission {
                hasPermission = await SpeechEngine.requestPermissions()
                guard hasPermission else {
                    fail("Koneko needs permission to use the microphone and speech recognition. You can allow it in System Settings → Privacy & Security.")
                    return
                }
            }
            // She may already have let go while the permission dialog was showing.
            guard status == .listening, !Task.isCancelled else { return }
            do {
                try engine.start(locale: Self.locale(for: language)) { [weak self] update in
                    Task { @MainActor in self?.handle(update) }
                }
            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    /// Stops listening and returns what was heard (nil if nothing).
    func finish() async -> Result? {
        guard status == .listening else { return nil }
        status = .finishing
        await startTask?.value
        engine.stop()

        // Wait for the final transcript, but never more than 2 seconds.
        if !receivedFinal {
            await withCheckedContinuation { continuation in
                finalContinuation = continuation
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    self.resumeFinal()
                }
            }
        }
        engine.cancel()
        status = .idle
        level = 0

        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : Result(text: text, alternatives: alternatives)
    }

    private func handle(_ update: SpeechEngine.Update) {
        switch update {
        case .level(let value):
            if status == .listening { level = value }
        case .transcript(let best, let alternatives, _):
            transcript = best
            self.alternatives = alternatives
        case .finished:
            // Errors here are usually "no speech detected"; an empty transcript covers that.
            receivedFinal = true
            resumeFinal()
        }
    }

    private func resumeFinal() {
        finalContinuation?.resume()
        finalContinuation = nil
    }

    private func fail(_ message: String) {
        engine.cancel()
        errorMessage = message
        status = .idle
        level = 0
        resumeFinal()
    }

    private static func locale(for language: InputLanguage) -> Locale {
        switch language {
        case .english:
            Locale.current.language.languageCode == .english ? Locale.current : Locale(identifier: "en-US")
        case .japanese:
            Locale(identifier: "ja-JP")
        }
    }
}
