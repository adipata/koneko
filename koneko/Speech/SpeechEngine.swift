import AVFoundation
import Speech

/// Low-level microphone + speech recognition plumbing.
///
/// This type is deliberately `nonisolated`: the audio tap and the recognition callbacks run on
/// background threads, so they must not be main-actor closures. Every update is handed to
/// `onUpdate`, which the caller hops back to the main actor. Start/stop are only called from
/// the main actor.
nonisolated final class SpeechEngine: @unchecked Sendable {
    nonisolated enum Update: Sendable {
        case level(Float)
        case transcript(best: String, alternatives: [String], isFinal: Bool)
        case finished(error: String?)
    }

    nonisolated enum StartError: LocalizedError {
        case recognizerUnavailable(String)
        case noMicrophone

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable(let language):
                "Speech recognition for \(language) isn't available on this device right now."
            case .noMicrophone:
                "No microphone was found."
            }
        }
    }

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    static func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechStatus == .authorized else { return false }
        #if os(iOS)
        return await AVAudioApplication.requestRecordPermission()
        #else
        return await AVCaptureDevice.requestAccess(for: .audio)
        #endif
    }

    func start(locale: Locale, onUpdate: @escaping @Sendable (Update) -> Void) throws {
        cancel()

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw StartError.recognizerUnavailable(locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
        }
        self.recognizer = recognizer

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .search // short words and phrases
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true // keep her voice on the device
        }
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw StartError.noMicrophone }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            onUpdate(.level(Self.level(of: buffer)))
        }
        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { result, error in
            if let result {
                let best = result.bestTranscription.formattedString
                let alternatives = result.transcriptions.map(\.formattedString).filter { $0 != best }
                onUpdate(.transcript(best: best, alternatives: alternatives, isFinal: result.isFinal))
                if result.isFinal {
                    onUpdate(.finished(error: nil))
                    return
                }
            }
            if let error {
                onUpdate(.finished(error: error.localizedDescription))
            }
        }
    }

    /// Stops listening; the recognizer then delivers its final result.
    func stop() {
        stopAudio()
        request?.endAudio()
    }

    func cancel() {
        stopAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    private func stopAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    /// Rough loudness (0...1) of a buffer, for the "listening" animation.
    private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) {
            sum += samples[index] * samples[index]
        }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        let decibels = 20 * log10(max(rms, 0.000_01))
        return max(0, min(1, (decibels + 50) / 40)) // -50 dB → 0, -10 dB → 1
    }
}
