#if os(iOS)
import PhotosUI
import SwiftUI
import UIKit

/// The 📷 button under an English → 日本語 flash card (a word from My words, or a kana or kanji
/// in Learn): she writes the answer on paper, takes a photo, and the AI says what to fix, from
/// the word itself down to how each character is formed.
struct HandwritingCheckButton: View {
    let card: FlashCard
    /// A word from My words (rather than a kana or kanji she is learning).
    let isWord: Bool
    let model: String

    @State private var showsCamera = false
    @State private var showsLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    /// The photo just taken, shown once the camera has closed.
    @State private var takenPhoto: UIImage?
    @State private var check: PendingCheck?

    var body: some View {
        Menu {
            if CameraPicker.isAvailable {
                Button("Take a photo", systemImage: "camera") { showsCamera = true }
            }
            Button("Choose a photo", systemImage: "photo.on.rectangle") { showsLibrary = true }
        } label: {
            Label("Check my writing", systemImage: "camera")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .font(.title2)
        .accessibilityHint("Take a photo of what you wrote by hand")
        .fullScreenCover(isPresented: $showsCamera, onDismiss: showTakenPhoto) {
            CameraPicker { takenPhoto = $0 }
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showsLibrary, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) {
            guard let item = libraryItem else { return }
            libraryItem = nil
            Task { await load(item) }
        }
        .sheet(item: $check) { check in
            HandwritingCheckView(image: check.image, card: check.card, isWord: isWord, model: model)
        }
    }

    private func showTakenPhoto() {
        guard let takenPhoto else { return }
        self.takenPhoto = nil
        check = PendingCheck(image: takenPhoto, card: card)
    }

    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        check = PendingCheck(image: image, card: card)
    }
}

private struct PendingCheck: Identifiable {
    let id = UUID()
    let image: UIImage
    /// The card when the photo was taken.
    let card: FlashCard
}

/// The photo with a frame around her word, then the AI's advice in a box.
struct HandwritingCheckView: View {
    let image: UIImage
    let card: FlashCard
    let isWord: Bool
    let model: String

    @Environment(\.dismiss) private var dismiss
    @State private var cropRect = CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.4)
    @State private var cropped: UIImage?
    @State private var checking: Task<Void, Never>?
    @State private var advice: HandwritingAdvice?
    @State private var problem: AIProblem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let advice, let cropped {
                    Image(uiImage: cropped)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    AdviceBox(advice: advice, expected: card.japanese)
                } else {
                    PhotoCropView(image: image, cropRect: $cropRect)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    actions
                        .frame(minHeight: 90)
                }
            }
            .padding()
            .navigationTitle("Check my writing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: advice == nil ? .cancellationAction : .confirmationAction) {
                    Button(advice == nil ? "Cancel" : "Done") {
                        checking?.cancel()
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            if checking != nil {
                ProgressView("Looking at your writing…")
            } else if let problem {
                AIProblemView(problem: problem, retry: runCheck)
            } else {
                Text("Move the frame around what you wrote.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Check it", systemImage: "sparkles", action: runCheck)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }

    private func runCheck() {
        problem = nil
        let crop = image.cropped(to: cropRect, maxSide: 1024)
        checking = Task {
            defer { checking = nil }
            do {
                let result = try await HandwritingCoach.check(crop, card: card, isWord: isWord, model: model)
                if result.read.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    problem = AIProblem(
                        title: "I couldn't find your writing",
                        message: "Put the frame closer around your writing, or take a clearer photo.",
                        systemImage: "eye.slash", canRetry: false
                    )
                } else {
                    cropped = crop
                    advice = result
                }
            } catch is CancellationError {
                return
            } catch {
                problem = AIProblem(error)
            }
        }
    }
}

/// The advice, from the word as a whole down to each character.
private struct AdviceBox: View {
    let advice: HandwritingAdvice
    let expected: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(advice.rightWord ? "✅" : "✏️")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You wrote \(advice.read)")
                            .font(.title3.bold())
                        if !advice.rightWord {
                            Text("It should be \(expected)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text(advice.word)

                if !advice.characters.isEmpty {
                    Divider()
                    ForEach(Array(advice.characters.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 12) {
                            Text(item.character)
                                .font(.handwriting(size: 34))
                                .frame(minWidth: 44)
                            Text(item.advice)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                if !advice.overall.isEmpty {
                    Divider()
                    Text(advice.overall)
                        .italic()
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.blue.opacity(0.3)))
        .frame(maxWidth: 560)
    }
}
#endif
