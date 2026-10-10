import AVFoundation
import Observation

/// Says Japanese words aloud with the best Japanese voice installed on the device.
///
/// Speaking straight through `AVSpeechSynthesizer` often clips the first time: the audio
/// hardware (and Bluetooth headphones) are still waking up, especially right after the
/// microphone was used, so the start and end of short words get cut. Instead, each word is
/// first rendered to a small audio file (cached, so it's instant next time) and then played
/// with `AVAudioPlayer` after a short lead-in. If rendering fails, it falls back to speaking live.
@Observable
final class Pronouncer {
    static let shared = Pronouncer()

    private let synthesizer = AVSpeechSynthesizer()
    private let renderer = SpeechRenderer()
    private let player = AudioFilePlayer()
    private var playTask: Task<Void, Never>?
    private(set) var voice: AVSpeechSynthesisVoice?

    private init() {
        refreshVoice()
    }

    /// Picks the highest-quality Japanese voice (premium > enhanced > default).
    func refreshVoice() {
        voice = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "ja-JP" && !$0.voiceTraits.contains(.isNoveltyVoice) }
            .max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }

    var voiceDescription: String {
        guard let voice else { return "No Japanese voice installed" }
        switch voice.quality {
        case .premium: return "\(voice.name) (Premium)"
        case .enhanced: return "\(voice.name) (Enhanced)"
        default: return "\(voice.name) (basic quality)"
        }
    }

    var hasGoodVoice: Bool {
        (voice?.quality.rawValue ?? 0) >= AVSpeechSynthesisVoiceQuality.enhanced.rawValue
    }

    func speak(_ text: String, slow: Bool = false) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        stop()

        let request = SpeechRenderer.Request(
            text: text,
            voiceIdentifier: voice?.identifier,
            rate: AVSpeechUtteranceDefaultSpeechRate * (slow ? 0.55 : 0.9)
        )
        playTask = Task {
            await AudioSessionQueue.activatePlayback()
            let file = await renderer.audioFile(for: request)
            guard !Task.isCancelled else { return }
            if let file, await player.play(file) { return }
            guard !Task.isCancelled else { return }
            speakLive(request)
        }
    }

    /// Renders a word in the background so it plays instantly later (e.g. when a card appears).
    func prepare(_ text: String, slow: Bool = false) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let request = SpeechRenderer.Request(
            text: text,
            voiceIdentifier: voice?.identifier,
            rate: AVSpeechUtteranceDefaultSpeechRate * (slow ? 0.55 : 0.9)
        )
        Task { _ = await renderer.audioFile(for: request) }
    }

    func stop() {
        playTask?.cancel()
        player.stop()
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: Private

    private func speakLive(_ request: SpeechRenderer.Request) {
        let utterance = request.utterance()
        utterance.preUtteranceDelay = 0.15
        utterance.postUtteranceDelay = 0.2
        synthesizer.speak(utterance)
    }
}

/// Renders speech to cached audio files (Caches/Pronunciations), one per word, voice and speed.
nonisolated final class SpeechRenderer: @unchecked Sendable {
    nonisolated struct Request: Sendable {
        let text: String
        let voiceIdentifier: String?
        let rate: Float

        func utterance() -> AVSpeechUtterance {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voiceIdentifier.flatMap(AVSpeechSynthesisVoice.init(identifier:))
                ?? AVSpeechSynthesisVoice(language: "ja-JP")
            utterance.rate = rate
            return utterance
        }

        /// A file name that is safe and unique for this text, voice and speed.
        var cacheName: String {
            let key = "\(voiceIdentifier ?? "ja-JP")|\(Int(rate * 1000))|\(text)"
            var hash: UInt64 = 0xcbf2_9ce4_8422_2325 // FNV-1a
            for byte in key.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01b3
            }
            return String(hash, radix: 16) + ".caf"
        }
    }

    private let folder: URL
    private let lock = NSLock()
    /// Synthesizers must stay alive until they finish writing.
    private var active: [ObjectIdentifier: AVSpeechSynthesizer] = [:]

    init() {
        folder = URL.cachesDirectory.appending(path: "Pronunciations")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    func audioFile(for request: Request) async -> URL? {
        let url = folder.appending(path: request.cacheName)
        if FileManager.default.fileExists(atPath: url.path) { return url }

        return await withCheckedContinuation { continuation in
            let synthesizer = AVSpeechSynthesizer()
            let id = ObjectIdentifier(synthesizer)
            lock.withLock { active[id] = synthesizer }
            let state = RenderState(finalURL: url, temporaryURL: folder.appending(path: UUID().uuidString + ".caf"))

            let finish: @Sendable (Bool) -> Void = { [weak self] success in
                guard let result = state.finish(success: success) else { return } // already finished
                self?.lock.withLock { _ = self?.active.removeValue(forKey: id) }
                continuation.resume(returning: result.url)
            }

            synthesizer.write(request.utterance()) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    finish(true) // an empty buffer marks the end
                } else if !state.append(pcm) {
                    finish(false)
                }
            }
            // Never wait forever (some voices don't report the end reliably).
            DispatchQueue.global().asyncAfter(deadline: .now() + 6) { finish(state.hasAudio) }
        }
    }
}

/// Collects the rendered audio into a file; thread-safe, finishes only once.
private nonisolated final class RenderState: @unchecked Sendable {
    private let lock = NSLock()
    private let finalURL: URL
    private let temporaryURL: URL
    private var file: AVAudioFile?
    private var done = false

    init(finalURL: URL, temporaryURL: URL) {
        self.finalURL = finalURL
        self.temporaryURL = temporaryURL
    }

    var hasAudio: Bool { lock.withLock { file != nil } }

    func append(_ buffer: AVAudioPCMBuffer) -> Bool {
        lock.withLock {
            guard !done else { return true }
            do {
                if file == nil {
                    file = try AVAudioFile(
                        forWriting: temporaryURL,
                        settings: buffer.format.settings,
                        commonFormat: buffer.format.commonFormat,
                        interleaved: buffer.format.isInterleaved
                    )
                }
                try file?.write(from: buffer)
                return true
            } catch {
                return false
            }
        }
    }

    struct Result {
        /// The cached audio file, or nil if rendering failed.
        let url: URL?
    }

    /// Returns nil if it had already finished (so the caller resumes only once).
    func finish(success: Bool) -> Result? {
        lock.withLock {
            guard !done else { return nil }
            done = true
            let hadAudio = file != nil
            file = nil // closes the file
            guard success, hadAudio else {
                try? FileManager.default.removeItem(at: temporaryURL)
                return Result(url: nil)
            }
            try? FileManager.default.removeItem(at: finalURL)
            do {
                try FileManager.default.moveItem(at: temporaryURL, to: finalURL)
                return Result(url: finalURL)
            } catch {
                return Result(url: nil)
            }
        }
    }
}

extension WordCandidate {
    /// What to say aloud: the kana reading, so kanji are never misread (今日 → きょう).
    var spokenText: String {
        reading.isEmpty ? japanese : reading
    }

    /// The sound for the character at `index` in `japanese`, or nil if it shouldn't be spoken alone.
    /// Kana say their own sound; a kanji says the reading of its part in this word.
    func spokenText(forCharacterAt index: Int) -> String? {
        var offset = 0
        for part in parts {
            let characters = Array(part.text)
            if index < offset + characters.count {
                let character = characters[index - offset]
                if JapaneseText.containsKanji(String(character)) {
                    return part.reading.isEmpty ? String(character) : part.reading
                }
                let position = index - offset
                // A small ゃゅょ… is said together with the kana before it: しょ → "sho".
                if JapaneseText.isSmallYouon(character) {
                    guard position > 0, JapaneseText.isKana(String(characters[position - 1])) else { return nil }
                    return JapaneseText.hiragana(String(characters[position - 1]) + String(character))
                }
                // っ and the long-vowel mark don't make sense on their own.
                if "っッー".contains(character) || !JapaneseText.isKana(String(character)) {
                    return nil
                }
                // A kana followed by a small one is one syllable, as its romaji shows.
                if position + 1 < characters.count, JapaneseText.isSmallYouon(characters[position + 1]) {
                    return JapaneseText.hiragana(String(character) + String(characters[position + 1]))
                }
                return JapaneseText.hiragana(String(character))
            }
            offset += characters.count
        }
        return nil
    }
}
