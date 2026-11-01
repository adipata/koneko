#if os(iOS)
import SwiftUI
import UIKit
import VisionKit

/// A photo (or pasted picture) of a page: she either selects the text in it (read on the device
/// with Live Text, only the text is sent) or crops a part of it (the picture is sent, e.g. one manga
/// panel), and the AI explains it. Several parts of the same photo can be explained one after another.
struct ReadingScanView: View {
    let image: UIImage
    let readingID: Reading.ID
    let store: ReadingStore
    let model: AIModel
    let openSettings: () -> Void
    var onLookUp: ((String) -> Void)?

    private enum Mode: Hashable {
        case picture
        case text
    }

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode

    @State private var analysis: ImageAnalysis?
    @State private var analysisFinished = false
    @State private var selectedText = ""

    @State private var cropRect = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    @State private var explaining: Task<Void, Never>?
    @State private var problem: AIProblem?
    /// The part just explained, shown instead of the photo.
    @State private var result: ReadingEntry?

    init(image: UIImage, reading: Reading, store: ReadingStore, model: AIModel, openSettings: @escaping () -> Void, onLookUp: ((String) -> Void)? = nil) {
        self.image = image
        readingID = reading.id
        self.store = store
        self.model = model
        self.openSettings = openSettings
        self.onLookUp = onLookUp
        // Manga text is in bubbles, often vertical: cropping the panel works best.
        _mode = State(initialValue: reading.kind == .manga ? .picture : .text)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    resultView(result)
                } else {
                    photoView
                }
            }
            .navigationTitle(result == nil ? "What to explain" : "Explanation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if result == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            explaining?.cancel()
                            dismiss()
                        }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .task { await analyze() }
        .onChange(of: mode) {
            problem = nil
        }
    }

    // MARK: Photo

    private var photoView: some View {
        VStack(spacing: 16) {
            Picker("How to explain", selection: $mode) {
                Text("✂️ Crop the picture").tag(Mode.picture)
                Text("🔤 Select the text").tag(Mode.text)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 420)
            .disabled(explaining != nil)

            Group {
                switch mode {
                case .picture:
                    PhotoCropView(image: image, cropRect: $cropRect)
                case .text:
                    LiveTextImage(image: image, analysis: analysis, selectedText: $selectedText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            actions
                .frame(minHeight: 90)
        }
        .padding()
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            if explaining != nil {
                ProgressView("Reading and explaining…")
            } else if let problem {
                AIProblemView(problem: problem, retry: explain) {
                    dismiss()
                    openSettings()
                }
            } else {
                switch mode {
                case .picture: pictureActions
                case .text: textActions
                }
            }
        }
    }

    private var pictureActions: some View {
        VStack(spacing: 10) {
            Text("Move the frame around the part to explain (for a manga, one panel).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            explainButton
        }
    }

    @ViewBuilder
    private var textActions: some View {
        if !analysisFinished {
            ProgressView("Finding the words…")
        } else if transcript.isEmpty {
            Text("I can't find text to select in this picture. Try ✂️ Crop the picture.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 10) {
                Text("Touch and hold a word, then drag to select the words to explain.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if textToExplain != nil {
                    explainButton
                }
            }
        }
    }

    private var explainButton: some View {
        Button(action: explain) {
            Label(explainTitle, systemImage: "sparkles")
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 360)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var explainTitle: String {
        guard mode == .text, let text = textToExplain else { return "Explain it" }
        return selected.isEmpty ? "Explain all the text" : "Explain “\(text)”"
    }

    private var transcript: String {
        (analysis?.transcript ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selected: String {
        selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The selected text; or all of it when nothing is selected and it isn't too long.
    private var textToExplain: String? {
        if !selected.isEmpty { return selected }
        return !transcript.isEmpty && transcript.count <= 200 ? transcript : nil
    }

    private func analyze() async {
        defer { analysisFinished = true }
        guard ImageAnalyzer.isSupported else { return }
        var configuration = ImageAnalyzer.Configuration([.text])
        configuration.locales = ["ja-JP", "en-US"]
        analysis = try? await ImageAnalyzer().analyze(image, configuration: configuration)
    }

    // MARK: Asking the AI

    private func explain() {
        guard let reading = store.reading(readingID) else { return }
        let input: ReadingExplainer.Input
        switch mode {
        case .text:
            guard let text = textToExplain else { return }
            input = .text(text)
        case .picture:
            // Large enough for small manga lettering.
            guard let jpeg = image.cropped(to: cropRect, maxSide: 1536).jpegData(compressionQuality: 0.85) else { return }
            input = .picture(jpeg)
        }
        problem = nil
        explaining = Task {
            defer { explaining = nil }
            do {
                let entry = try await ReadingExplainer.explain(input, in: reading, model: model)
                store.add(entry, to: readingID)
                result = entry
            } catch is CancellationError {
                return
            } catch ReadingExplainerError.nothingToRead {
                problem = AIProblem(
                    title: "I couldn't find Japanese text",
                    message: "Try putting the frame closer around the words, or take a clearer photo.",
                    systemImage: "eye.slash", canRetry: false
                )
            } catch {
                problem = AIProblem(error, provider: model.provider)
            }
        }
    }

    // MARK: Result

    /// Closes the sheet, then looks the words up in Write.
    private func lookUpAndClose(_ text: String) {
        dismiss()
        onLookUp?(text)
    }

    private func resultView(_ entry: ReadingEntry) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ReadingEntryContent(entry: entry, onLookUp: onLookUp == nil ? nil : lookUpAndClose)
                Button("Explain another part of this photo", systemImage: "viewfinder") {
                    selectedText = ""
                    result = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                Text("Saved in this reading's history.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
#endif
