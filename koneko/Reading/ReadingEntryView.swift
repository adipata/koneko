#if os(iOS)
import SwiftUI

/// One scanned part: the Japanese text (selectable, to copy parts of it) and the AI's
/// explanation saved with it.
struct ReadingEntryContent: View {
    let entry: ReadingEntry
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
        HStack(alignment: .firstTextBaseline, spacing: 12) {
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
        }
        .contextMenu {
            Button("Copy “\(japanese)”", systemImage: "doc.on.doc") { Clipboard.copy(japanese) }
            if let onLookUp {
                Button("Look up in Write", systemImage: "pencil.and.scribble") { onLookUp(japanese) }
            }
        }
    }
}

/// A saved part, opened from a reading's history.
struct ReadingEntryView: View {
    let entry: ReadingEntry
    var onLookUp: ((String) -> Void)?

    var body: some View {
        ScrollView {
            ReadingEntryContent(entry: entry, onLookUp: onLookUp)
                .padding()
        }
        .navigationTitle(entry.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
