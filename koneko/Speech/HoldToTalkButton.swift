import SwiftUI

/// A big microphone button: press and hold to speak, let go to look the word up.
struct HoldToTalkButton: View {
    let speech: SpeechInput
    let language: InputLanguage
    let onResult: (SpeechInput.Result) -> Void

    /// Resets automatically if the gesture is cancelled (e.g. by scrolling), so we never get stuck listening.
    @GestureState private var isPressed = false
    @State private var pressStart = Date.now
    @State private var hint: String?

    private var isListening: Bool { speech.status == .listening }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Grows with her voice while listening.
                Circle()
                    .fill(Color.red.opacity(0.18))
                    .frame(width: 96, height: 96)
                    .scaleEffect(isListening ? 1 + CGFloat(speech.level) * 0.6 : 0.8)
                    .animation(.easeOut(duration: 0.12), value: speech.level)

                Circle()
                    .fill(isListening ? Color.red : Color.accentColor)
                    .frame(width: 84, height: 84)
                    .shadow(radius: isPressed ? 2 : 6, y: isPressed ? 1 : 3)

                if speech.status == .finishing {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 140, height: 140)
            .scaleEffect(isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.2), value: isPressed)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, pressed, _ in pressed = true }
            )
            .onChange(of: isPressed) { _, pressed in
                pressed ? pressBegan() : pressEnded()
            }
            .accessibilityElement()
            .accessibilityLabel("Hold to talk")
            .accessibilityAddTraits(.isButton)

            Text(caption)
                .font(.headline)
                .foregroundStyle(isListening ? Color.red : Color.secondary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 44)

            if let message = speech.errorMessage {
                Label(message, systemImage: "mic.slash")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var caption: String {
        if isListening {
            return speech.transcript.isEmpty ? "Listening… 👂" : "“\(speech.transcript)”"
        }
        if speech.status == .finishing {
            return speech.transcript.isEmpty ? "…" : "“\(speech.transcript)”"
        }
        if let hint { return hint }
        switch language {
        case .english: return "Hold the button and say a word"
        case .japanese: return "ボタンをおしながら はなしてね"
        }
    }

    private func pressBegan() {
        pressStart = .now
        hint = nil
        speech.start(language: language)
    }

    private func pressEnded() {
        let heldFor = Date.now.timeIntervalSince(pressStart)
        Task {
            if let result = await speech.finish() {
                onResult(result)
            } else if speech.errorMessage == nil {
                hint = heldFor < 0.6
                    ? "Keep holding the button while you speak 🙂"
                    : "I didn't hear a word. Try again!"
            }
        }
    }
}
