import SwiftUI

/// The chosen word: emoji, the word with furigana, its reading and meaning.
struct WordCardView: View {
    let word: WordCandidate
    let showRomaji: Bool
    var showFurigana = true
    /// The word as adults write it (before the writing style was applied), for "Copy" options.
    var original: WordCandidate?

    @State private var copiedText: String?
    @State private var copiedResetTask: Task<Void, Never>?

    private var natural: WordCandidate { original ?? word }

    var body: some View {
        VStack(spacing: 8) {
            if !word.emoji.isEmpty {
                Text(word.emoji).font(.system(size: 56))
            }
            FuriganaText(parts: word.parts, showFurigana: showFurigana)
                .contextMenu { copyOptions }
            HStack(spacing: 16) {
                Button("Say it", systemImage: "speaker.wave.2.fill") {
                    Pronouncer.shared.speak(word.spokenText)
                }
                Button("Say it slowly", systemImage: "tortoise.fill") {
                    Pronouncer.shared.speak(word.spokenText, slow: true)
                }
                Button("Copy", systemImage: "doc.on.doc") {
                    copy(word.japanese)
                }
                .contextMenu { copyOptions }
            }
            .labelStyle(.iconOnly)
            .font(.title2)
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            if showRomaji, !word.romaji.isEmpty {
                Text(word.romaji)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            if !word.meaning.isEmpty {
                Text(word.meaning)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.orange.opacity(0.08)))
        .overlay(alignment: .top) {
            if let copiedText {
                Label("Copied “\(copiedText)”", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.regularMaterial))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: copiedText)
    }

    /// Long-press (iPad/iPhone) or right-click (Mac) menu with the different ways to copy.
    @ViewBuilder
    private var copyOptions: some View {
        Button("Copy “\(word.japanese)”", systemImage: "doc.on.doc") { copy(word.japanese) }
        if natural.japanese != word.japanese {
            Button("Copy as adults write it: \(natural.japanese)", systemImage: "doc.on.doc") { copy(natural.japanese) }
        }
        if !word.reading.isEmpty, word.reading != word.japanese {
            Button("Copy in hiragana: \(word.reading)", systemImage: "doc.on.doc") { copy(word.reading) }
        }
        if !word.romaji.isEmpty {
            Button("Copy romaji: \(word.romaji)", systemImage: "doc.on.doc") { copy(word.romaji) }
        }
    }

    private func copy(_ text: String) {
        Clipboard.copy(text)
        copiedText = text
        copiedResetTask?.cancel()
        copiedResetTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            copiedText = nil
        }
    }
}

/// Shows each part of a word with its reading above it when it contains kanji.
struct FuriganaText: View {
    let parts: [WordCandidate.Part]
    var showFurigana = true

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                VStack(spacing: 0) {
                    let needsReading = showFurigana && JapaneseText.containsKanji(part.text) && !part.reading.isEmpty
                    Text(needsReading ? part.reading : " ")
                        .font(.handwriting(size: 18))
                        .foregroundStyle(.orange)
                    Text(part.text)
                        .font(.handwriting(size: 60))
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
    }
}

/// "Did you mean…?" choices when there's more than one possible word.
struct CandidatePicker: View {
    let candidates: [WordCandidate]
    @Binding var selection: WordCandidate?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Which one did you mean?")
                .font(.headline)
            FlowLayout(spacing: 10, lineSpacing: 10) {
                ForEach(candidates) { candidate in
                    let isSelected = candidate == selection
                    Button {
                        selection = candidate
                    } label: {
                        VStack(spacing: 4) {
                            Text(candidate.emoji.isEmpty ? "❓" : candidate.emoji).font(.largeTitle)
                            Text(candidate.japanese).font(.handwriting(size: 26))
                            Text(candidate.meaning)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 130, height: 130)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isSelected ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 3)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
