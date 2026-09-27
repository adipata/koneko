import SwiftUI

/// Shows each part of a word with its reading above it when it contains kanji.
struct FuriganaText: View {
    let parts: [WordCandidate.Part]
    var showFurigana = true
    /// Size of the main characters; the reading above is 30% of it.
    var size: CGFloat = 60

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                VStack(spacing: 0) {
                    let needsReading = showFurigana && JapaneseText.containsKanji(part.text) && !part.reading.isEmpty
                    Text(needsReading ? part.reading : " ")
                        .font(.handwriting(size: size * 0.3))
                        .foregroundStyle(.orange)
                    Text(part.text)
                        .font(.handwriting(size: size))
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
    }
}
