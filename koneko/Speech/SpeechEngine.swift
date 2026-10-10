import AVFoundation
import Speech

/// Low-level microphone + speech recognition plumbing.
///
/// This type is deliberately `nonisolated`: the audio tap and the recognition callbacks run on
/// background threads, so they must not be main-actor closures. Updates are delivered, in order,
/// through an `AsyncStream`. Start/stop are only called from the main actor.
nonisolated final class SpeechEngine: @unchecked Sendable {
    nonisolated enum Update: Sendable {
        case level(Float)
        case transcript(best: String, alternatives: [String])
        case finished(Failure?)
    }

    nonisolated struct Failure: Sendable {
        let domain: String
        let code: Int
        let message: String

        /// "No speech detected": not really an error, she just didn't say anything.
        var isNoSpeech: Bool {
            (domain == "kAFAssistantErrorDomain" && [203, 1110].contains(code))
                || (domain == "kLSRErrorDomain" && code == 301 && message.localizedCaseInsensitiveContains("speech"))
        }

        /// We cancelled the request ourselves.
        var isCancellation: Bool {
            (domain == "kAFAssistantErrorDomain" && code == 216) || (domain == "kLSRErrorDomain" && code == 301)
        }
    }

    nonisolated enum StartError: LocalizedError {
        case recognizerUnavailable(String)
        case noMicrophone
        case audioBusy(String)

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable(let language):
                "Speech recognition for \(language) isn't available on this device right now."
            case .noMicrophone:
                "The microphone isn't available right now. If another app is using it (a call, a video, a recording), close it and try again."
            case .audioBusy(let detail):
                "Another app is using the microphone or sound right now. Close it or pause it, then try again. (\(detail))"
            }
        }
    }

    /// Recreated for every recording: after another app used the audio hardware (or the
    /// microphone changed, e.g. AirPods connecting), an old engine can report a 0 Hz input.
    private var audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: AsyncStream<Update>.Continuation?

    /// Copy of the audio, so we can try again with server recognition if on-device fails.
    private let recordingLock = NSLock()
    private var recording: [AVAudioPCMBuffer] = []

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

    /// The best supported recognition locale for the language (e.g. en-LU → en-GB).
    static func locale(for languageCode: String, preferred: Locale) -> Locale {
        let supported = SFSpeechRecognizer.supportedLocales()
        let fallbacks = languageCode == "ja" ? ["ja-JP"] : ["en-GB", "en-US"]
        for identifier in [preferred.identifier(.bcp47)] + fallbacks {
            if let match = supported.first(where: { $0.identifier(.bcp47) == identifier }) {
                return match
            }
        }
        return supported.first { $0.language.languageCode?.identifier == languageCode }
            ?? Locale(identifier: fallbacks.last!)
    }

    /// Starts the microphone and live recognition.
    func start(locale: Locale) async throws -> AsyncStream<Update> {
        cancel()
        recordingLock.withLock { recording = [] }

        let recognizer = try makeRecognizer(locale: locale)

        #if os(iOS)
        // Off the main thread (can block), on the shared audio queue (keeps the order).
        do {
            try await AudioSessionQueue.run {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.record, mode: .measurement, options: .duckOthers)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            }
        } catch {
            // e.g. a phone or FaceTime call has priority over us.
            throw StartError.audioBusy((error as NSError).localizedDescription)
        }
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .search // short words and phrases
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true // keep her voice on the device
        }
        self.request = request

        // A fresh engine picks up the current microphone. Right after another app released the
        // audio hardware the input can briefly report no format, so give it a few tries.
        var format = AVAudioFormat()
        for attempt in 0..<4 {
            audioEngine = AVAudioEngine()
            format = audioEngine.inputNode.outputFormat(forBus: 0)
            if format.sampleRate > 0, format.channelCount > 0 { break }
            if attempt == 3 { throw StartError.noMicrophone }
            try await Task.sleep(for: .milliseconds(250))
        }
        let input = audioEngine.inputNode

        let (stream, continuation) = AsyncStream<Update>.makeStream()
        self.continuation = continuation

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            if let copy = buffer.copy() as? AVAudioPCMBuffer {
                self?.recordingLock.withLock { self?.recording.append(copy) }
            }
            continuation.yield(.level(Self.level(of: buffer)))
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            continuation.finish()
            self.continuation = nil
            throw StartError.audioBusy((error as NSError).localizedDescription)
        }

        task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(continuation))
        return stream
    }

    /// Whether the last `start` used on-device recognition.
    var usedOnDevice: Bool { request?.requiresOnDeviceRecognition ?? false }

    /// Runs server recognition on the audio recorded by the last `start`.
    func recognizeRecording(locale: Locale) throws -> AsyncStream<Update> {
        let buffers = recordingLock.withLock { recording }
        cancel()
        let recognizer = try makeRecognizer(locale: locale)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        request.taskHint = .search
        request.requiresOnDeviceRecognition = false
        buffers.forEach(request.append)
        request.endAudio()
        self.request = request

        let (stream, continuation) = AsyncStream<Update>.makeStream()
        self.continuation = continuation
        task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(continuation))
        return stream
    }

    /// Stops listening; the recognizer then delivers its final result.
    func stop() {
        stopAudio()
        request?.endAudio()
    }

    /// Stops everything immediately and ends the update stream.
    func cancel() {
        stopAudio()
        task?.cancel()
        task = nil
        request = nil
        continuation?.finish()
        continuation = nil
    }

    private func makeRecognizer(locale: Locale) throws -> SFSpeechRecognizer {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            let name = Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
            throw StartError.recognizerUnavailable(name)
        }
        self.recognizer = recognizer
        return recognizer
    }

    private static func resultHandler(
        _ continuation: AsyncStream<Update>.Continuation
    ) -> @Sendable (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { result, error in
            if let result {
                let best = result.bestTranscription.formattedString
                let alternatives = result.transcriptions.map(\.formattedString).filter { $0 != best }
                continuation.yield(.transcript(best: best, alternatives: alternatives))
                if result.isFinal {
                    continuation.yield(.finished(nil))
                    continuation.finish()
                    return
                }
            }
            if let error {
                let nsError = error as NSError
                continuation.yield(.finished(Failure(
                    domain: nsError.domain, code: nsError.code, message: nsError.localizedDescription
                )))
                continuation.finish()
            }
        }
    }

    private func stopAudio() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        #if os(iOS)
        AudioSessionQueue.queue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
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
