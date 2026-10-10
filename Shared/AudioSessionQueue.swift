import AVFoundation

/// One serial background queue for everything that touches the audio session or starts
/// playback. Those calls can block for a moment, so they must not run on the main thread
/// (Xcode's "AVAudioSession Hang Risk"), and keeping them on one queue preserves their order
/// (e.g. the microphone's "deactivate" always happens before the speaker's "activate").
nonisolated enum AudioSessionQueue {
    static let queue = DispatchQueue(label: "koneko.audio-session", qos: .userInitiated)

    static func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try work()) } catch { continuation.resume(throwing: error) }
            }
        }
    }

    static func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work()) }
        }
    }

    /// Switches the (iOS/watchOS) audio session to playback.
    static func activatePlayback() async {
        #if os(iOS) || os(watchOS)
        await run {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try? session.setActive(true)
        }
        #endif
    }
}

/// Plays audio files; all player work happens on the audio session queue.
nonisolated final class AudioFilePlayer: @unchecked Sendable {
    private var player: AVAudioPlayer?

    /// Starts playing after a short lead-in (so the hardware is awake). Returns false on failure.
    func play(_ url: URL, leadIn: TimeInterval = 0.12) async -> Bool {
        await AudioSessionQueue.run { [self] in
            player?.stop()
            guard let newPlayer = try? AVAudioPlayer(contentsOf: url) else { return false }
            player = newPlayer
            newPlayer.prepareToPlay()
            return newPlayer.play(atTime: newPlayer.deviceCurrentTime + leadIn)
        }
    }

    func stop() {
        AudioSessionQueue.queue.async { [self] in player?.stop() }
    }
}
