#if os(iOS)
import SwiftUI
import UIKit
import VisionKit

/// Picks words from a photo. Printed text is read on the device with Live Text and she selects
/// the words she wants; handwriting is cropped and read by the AI (only the cropped part is sent).
struct PhotoTextView: View {
    let image: UIImage
    /// The AI model that reads handwriting.
    let model: AIModel
    let onText: (String) -> Void
    let openSettings: () -> Void

    private enum Kind: Hashable {
        case printed
        case handwriting
    }

    @Environment(\.dismiss) private var dismiss
    @State private var kind = Kind.printed

    @State private var analysis: ImageAnalysis?
    @State private var analysisFinished = false
    @State private var selectedText = ""

    @State private var cropRect = CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.4)
    @State private var reading: Task<Void, Never>?
    @State private var problem: AIProblem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Kind of writing", selection: $kind) {
                    Text("🔤 Printed").tag(Kind.printed)
                    Text("✍️ Handwriting").tag(Kind.handwriting)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
                .disabled(reading != nil)

                Group {
                    switch kind {
                    case .printed:
                        LiveTextImage(image: image, analysis: analysis, selectedText: $selectedText)
                    case .handwriting:
                        PhotoCropView(image: image, cropRect: $cropRect)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Group {
                    switch kind {
                    case .printed: printedActions
                    case .handwriting: handwritingActions
                    }
                }
                .frame(minHeight: 90)
            }
            .padding()
            .navigationTitle("Words from a photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        reading?.cancel()
                        dismiss()
                    }
                }
            }
        }
        .task { await analyze() }
        .onChange(of: kind) {
            problem = nil
            selectedText = ""
        }
    }

    // MARK: Printed text (on the device)

    /// All the text found, if it's short enough to use without selecting.
    private var shortTranscript: String? {
        guard let text = analysis?.transcript.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, text.count <= 30 else { return nil }
        return text
    }

    @ViewBuilder
    private var printedActions: some View {
        let selected = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(spacing: 10) {
            if !analysisFinished {
                ProgressView("Finding the words…")
            } else if (analysis?.transcript ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("I can't find printed words in this photo. If they're written by hand, try ✍️ Handwriting.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Touch and hold a word, then drag to pick the words you want.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let text = selected.isEmpty ? shortTranscript : Optional(selected) {
                    useButton(text)
                }
            }
        }
    }

    private func useButton(_ text: String) -> some View {
        Button {
            onText(text)
            dismiss()
        } label: {
            Text("Use “\(text)”")
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 360)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private func analyze() async {
        defer { analysisFinished = true }
        guard ImageAnalyzer.isSupported else { return }
        var configuration = ImageAnalyzer.Configuration([.text])
        configuration.locales = ["ja-JP", "en-US"]
        analysis = try? await ImageAnalyzer().analyze(image, configuration: configuration)
    }

    // MARK: Handwriting (AI)

    @ViewBuilder
    private var handwritingActions: some View {
        VStack(spacing: 10) {
            if reading != nil {
                ProgressView("Reading the handwriting…")
            } else if let problem {
                AIProblemView(problem: problem, retry: readHandwriting) {
                    dismiss()
                    openSettings()
                }
            } else {
                Text("Move the frame around the words, then I'll ask the AI to read them.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Read it", systemImage: "sparkles", action: readHandwriting)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }

    private func readHandwriting() {
        problem = nil
        let crop = image.cropped(to: cropRect, maxSide: 1024)
        reading = Task {
            defer { reading = nil }
            do {
                let text = try await HandwritingReader.read(crop, model: model)
                if text.isEmpty {
                    problem = AIProblem(
                        title: "I couldn't read any words",
                        message: "Try putting the frame closer around the words, or take a clearer photo.",
                        systemImage: "eye.slash", canRetry: false
                    )
                } else {
                    onText(text)
                    dismiss()
                }
            } catch is CancellationError {
                return
            } catch {
                problem = AIProblem(error, provider: model.provider)
            }
        }
    }
}
#endif
