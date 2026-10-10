import SwiftUI

/// Shows each part of a word with its reading above it when it contains kanji.
/// Long words and sentences wrap onto new lines, and every character keeps the same size.
struct FuriganaText: View {
    let parts: [WordCandidate.Part]
    var showFurigana = true
    /// Size of the main characters; the reading above is 30% of it.
    var size: CGFloat = 60

    /// One piece that must stay together: a kanji part with its reading, or a single kana.
    private struct Unit {
        let text: String
        let reading: String?
    }

    private var units: [Unit] {
        parts.flatMap { part -> [Unit] in
            if showFurigana, JapaneseText.containsKanji(part.text), !part.reading.isEmpty {
                return [Unit(text: part.text, reading: part.reading)]
            }
            // No reading to keep on top, so the line may break between any two characters.
            return part.text.map { Unit(text: String($0), reading: nil) }
        }
    }

    /// Long texts get a little smaller (never below 60%), the same for every character.
    private var fontSize: CGFloat {
        let count = parts.reduce(0) { $0 + $1.text.count }
        return size * min(1, max(0.6, 7 / CGFloat(max(count, 1))))
    }

    var body: some View {
        let fontSize = fontSize
        FlowLayout(spacing: 2, lineSpacing: 4) {
            ForEach(Array(units.enumerated()), id: \.offset) { _, unit in
                VStack(spacing: 0) {
                    Text(unit.reading ?? " ")
                        .font(.handwriting(size: fontSize * 0.3))
                        .foregroundStyle(.orange)
                    Text(unit.text)
                        .font(.handwriting(size: fontSize))
                }
                .lineLimit(1)
                .fixedSize()
            }
        }
    }
}
