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
    /// Why nothing was recognized, when we can tell (silence, recognizer error…).
    private(set) var problem: String?

    private let engine = SpeechEngine()
    private var alternatives: [String] = []
    private var failure: SpeechEngine.Failure?
    private var loudestLevel: Float = 0
    private var locale = Locale(identifier: "en-US")
    private var hasPermission = false
    private var startTask: Task<Void, Never>?
    private var listenTask: Task<Void, Never>?

    func start(language: InputLanguage) {
        guard status == .idle else { return }
        Pronouncer.shared.stop()
        errorMessage = nil
        problem = nil
        transcript = ""
        alternatives = []
        failure = nil
        loudestLevel = 0
        listenTask = nil
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
                locale = Self.locale(for: language)
                let updates = try await engine.start(locale: locale)
                listenTask = Task { await consume(updates) }
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
        await waitForListenTask(seconds: 2.5)

        // On-device recognition can fail (e.g. its language files aren't installed yet).
        // Try once more with Apple's server recognition on the recorded audio.
        if transcript.isEmpty, let failure, !failure.isNoSpeech, !failure.isCancellation, engine.usedOnDevice {
            self.failure = nil
            if let updates = try? engine.recognizeRecording(locale: locale) {
                listenTask = Task { await consume(updates) }
                await waitForListenTask(seconds: 6)
            }
        }

        engine.cancel()
        status = .idle
        level = 0

        // Dictation adds sentence punctuation (。 or .), which isn't part of the word.
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if text.isEmpty {
            problem = explainEmptyResult()
            return nil
        }
        return Result(text: text, alternatives: alternatives)
    }

    private func consume(_ updates: AsyncStream<SpeechEngine.Update>) async {
        for await update in updates {
            switch update {
            case .level(let value):
                loudestLevel = max(loudestLevel, value)
                if status == .listening { level = value }
            case .transcript(let best, let alternatives):
                transcript = best
                self.alternatives = alternatives
            case .finished(let failure):
                self.failure = failure
            }
        }
    }

    /// Waits for the recognizer to finish, cancelling it after `seconds`.
    private func waitForListenTask(seconds: Double) async {
        guard let listenTask else { return }
        let timeout = Task {
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { engine.cancel() } // ends the stream
        }
        await listenTask.value
        timeout.cancel()
    }

    private func explainEmptyResult() -> String? {
        if loudestLevel < 0.1 {
            #if os(macOS)
            return "The microphone only picked up silence. Check the input device in System Settings → Sound → Input."
            #else
            return "The microphone only picked up silence. Try speaking a bit louder."
            #endif
        }
        if let failure, !failure.isNoSpeech, !failure.isCancellation {
            return "Speech recognition didn't work: \(failure.message) (\(failure.domain) \(failure.code))"
        }
        return nil
    }

    private func fail(_ message: String) {
        engine.cancel()
        errorMessage = message
        status = .idle
        level = 0
    }

    private static func locale(for language: InputLanguage) -> Locale {
        switch language {
        case .english: SpeechEngine.locale(for: "en", preferred: Locale.current)
        case .japanese: SpeechEngine.locale(for: "ja", preferred: Locale(identifier: "ja-JP"))
        }
    }
}
