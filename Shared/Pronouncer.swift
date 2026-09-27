import AVFoundation
import Observation

/// Says Japanese words aloud with the best Japanese voice installed on the device.
@Observable
final class Pronouncer {
    static let shared = Pronouncer()

    private let synthesizer = AVSpeechSynthesizer()
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

        #if os(iOS) || os(watchOS)
        // Hold-to-talk switches the session to recording; switch back to playback.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)
        #endif

        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * (slow ? 0.55 : 0.9)
        utterance.postUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
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
                // Small kana and the long-vowel mark don't make sense on their own.
                if "ゃゅょぁぃぅぇぉっャュョァィゥェォッー".contains(character) || !JapaneseText.isKana(String(character)) {
                    return nil
                }
                return JapaneseText.hiragana(String(character))
            }
            offset += characters.count
        }
        return nil
    }
}
