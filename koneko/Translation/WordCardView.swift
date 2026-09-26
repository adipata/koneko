import SwiftUI

/// The chosen word: emoji, the word with furigana, its reading and meaning.
struct WordCardView: View {
    let word: WordCandidate
    let showRomaji: Bool

    var body: some View {
        VStack(spacing: 8) {
            if !word.emoji.isEmpty {
                Text(word.emoji).font(.system(size: 56))
            }
            FuriganaText(parts: word.parts)
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
    }
}

/// Shows each part of a word with its reading above it when it contains kanji.
struct FuriganaText: View {
    let parts: [WordCandidate.Part]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                VStack(spacing: 0) {
                    let needsReading = JapaneseText.containsKanji(part.text) && !part.reading.isEmpty
                    Text(needsReading ? part.reading : " ")
                        .font(.system(size: 18))
                        .foregroundStyle(.orange)
                    Text(part.text)
                        .font(.system(size: 52, weight: .medium))
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(candidates) { candidate in
                        let isSelected = candidate == selection
                        Button {
                            selection = candidate
                        } label: {
                            VStack(spacing: 4) {
                                Text(candidate.emoji.isEmpty ? "❓" : candidate.emoji).font(.largeTitle)
                                Text(candidate.japanese).font(.title2)
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
}
