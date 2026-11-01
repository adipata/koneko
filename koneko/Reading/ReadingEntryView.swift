#if os(iOS)
import SwiftUI

/// One scanned part: the Japanese text (selectable, to copy parts of it) and the AI's
/// explanation saved with it.
struct ReadingEntryContent: View {
    let entry: ReadingEntry
    /// My words, to save words and kanji from the explanation.
    let history: HistoryStore
    var onLookUp: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                SelectableText(text: entry.text, textStyle: .title2, weight: .medium, onLookUp: onLookUp)
                HStack(spacing: 10) {
                    CopyButton(text: entry.text)
                    if !entry.explanation.kana.isEmpty {
                        Button("Listen", systemImage: "speaker.wave.2.fill") {
                            // The kana reading, so kanji are never misread.
                            Pronouncer.shared.speak(entry.explanation.kana)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.08)))

            let explanation = entry.explanation
            if !explanation.kana.isEmpty {
                section("In kana", systemImage: "character.textbox") {
                    SelectableText(text: explanation.kana, textStyle: .title3, onLookUp: onLookUp)
                }
            }
            if !explanation.translation.isEmpty {
                section("Meaning", systemImage: "globe") {
                    SelectableText(text: explanation.translation, textStyle: .body)
                }
            }
            if !explanation.explanation.isEmpty {
                section("How it works", systemImage: "lightbulb") {
                    SelectableText(text: explanation.explanation, textStyle: .body, onLookUp: onLookUp)
                }
            }
            if !explanation.words.isEmpty {
                section("Words", systemImage: "list.bullet") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(explanation.words.enumerated()), id: \.offset) { _, word in
                            pieceRow(word.japanese, reading: word.reading, meaning: word.meaning, note: word.note, large: false)
                        }
                    }
                }
            }
            if !explanation.kanji.isEmpty {
                section("Kanji", systemImage: "character.book.closed") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(explanation.kanji.enumerated()), id: \.offset) { _, kanji in
                            pieceRow(kanji.kanji, reading: kanji.reading, meaning: kanji.meaning, note: kanji.note, large: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private func section(_ title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.orange)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pieceRow(_ japanese: String, reading: String, meaning: String, note: String, large: Bool) -> some View {
        let word = Self.word(japanese, reading: reading, meaning: meaning)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(japanese)
                .font(large ? .largeTitle : .title3.weight(.medium))
                .frame(minWidth: large ? 48 : nil, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if !reading.isEmpty, reading != japanese {
                        Text(reading).foregroundStyle(.secondary)
                    }
                    Text(meaning)
                }
                if !note.isEmpty {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let word {
                saveButton(word)
            }
        }
        .contextMenu {
            if let word, !isSaved(word) {
                Button("Save to My words", systemImage: "plus.circle") { history.record(word) }
            }
            Button("Copy “\(japanese)”", systemImage: "doc.on.doc") { Clipboard.copy(japanese) }
            if let onLookUp {
                Button("Look up in Write", systemImage: "pencil.and.scribble") { onLookUp(japanese) }
            }
        }
    }

    private func saveButton(_ word: WordCandidate) -> some View {
        let saved = isSaved(word)
        return Button {
            history.record(word)
        } label: {
            Image(systemName: saved ? "checkmark.circle.fill" : "plus.circle")
                .font(.title3)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .tint(saved ? .green : .orange)
        .disabled(saved)
        .accessibilityLabel(saved ? "\(word.japanese) is in My words" : "Save \(word.japanese) to My words")
        .help(saved ? "In My words" : "Save to My words")
    }

    private func isSaved(_ word: WordCandidate) -> Bool {
        history.entries.contains { $0.id == word.id }
    }

    /// A word or kanji of the explanation as a My words entry; nil if it can't be one
    /// (not Japanese, or no kana reading).
    private static func word(_ japanese: String, reading: String, meaning: String) -> WordCandidate? {
        let kana = JapaneseText.isKana(japanese) ? japanese : reading
        let candidate = WordCandidate(
            japanese: japanese,
            reading: kana,
            romaji: "",
            meaning: meaning,
            emoji: "",
            isLoanword: JapaneseText.isKana(japanese) && JapaneseText.katakana(japanese) == japanese,
            parts: [WordCandidate.Part(text: japanese, reading: JapaneseText.hiragana(kana))]
        )
        return candidate.validated()
    }
}

/// A saved part, opened from a reading's history.
struct ReadingEntryView: View {
    let entry: ReadingEntry
    let history: HistoryStore
    var onLookUp: ((String) -> Void)?

    var body: some View {
        ScrollView {
            ReadingEntryContent(entry: entry, history: history, onLookUp: onLookUp)
                .padding()
        }
        .navigationTitle(entry.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
