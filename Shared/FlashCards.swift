import SwiftUI

/// Which side of a flash card is shown first.
enum FlashDirection: String, CaseIterable, Identifiable {
    case japaneseFirst
    case englishFirst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .japaneseFirst: "日本語 → English"
        case .englishFirst: "English → 日本語"
        }
    }
}

/// A set of flash cards: one alphabet, or the kanji of one school grade.
enum FlashDeck: Hashable, Identifiable {
    case kana(KanaScript)
    case kanji(grade: Int)
    /// A set she made herself.
    case custom(FlashSet)

    var id: String {
        switch self {
        case .kana(let script): script.rawValue
        case .kanji(let grade): "kanji-\(grade)"
        case .custom(let set): "set-\(set.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .kana(let script): script.title
        case .kanji(let grade): grade == 7 ? "Kanji · Secondary" : "Kanji · Grade \(grade)"
        case .custom(let set): set.name
        }
    }

    func cards(kanji: KanjiLibrary) -> [FlashCard] {
        switch self {
        case .kana(let script):
            return KanaChart.allCells.map { Self.kanaCard($0, script: script) }
        case .kanji(let grade):
            return kanji.kanji(grade: grade).map(Self.kanjiCard)
        case .custom(let set):
            switch set.kind {
            case .hiragana, .katakana:
                let script: KanaScript = set.kind == .katakana ? .katakana : .hiragana
                let wanted = Set(set.items)
                return KanaChart.allCells.filter { wanted.contains($0.id) }.map { Self.kanaCard($0, script: script) }
            case .kanji:
                return set.items.compactMap { kanji.info(for: $0) }.map(Self.kanjiCard)
            }
        }
    }

    private static func kanaCard(_ cell: KanaCell, script: KanaScript) -> FlashCard {
        FlashCard(japanese: script.text(cell.hiragana), english: cell.romaji, detail: nil, speech: cell.hiragana)
    }

    private static func kanjiCard(_ info: KanjiInfo) -> FlashCard {
        let reading = info.mainReading
        return FlashCard(
            japanese: info.character,
            english: info.meanings.prefix(2).joined(separator: ", "),
            detail: reading.isEmpty ? nil : "\(reading) · \(JapaneseText.romaji(reading))",
            speech: reading
        )
    }
}

struct FlashCard: Identifiable, Equatable {
    let id = UUID()
    /// The kana or kanji.
    let japanese: String
    /// Romaji (kana) or meaning (kanji).
    let english: String
    /// Extra line on the English side, e.g. the kanji's reading.
    let detail: String?
    /// What to say aloud.
    let speech: String
}

/// Picks random cards forever, never the same one twice in a row. No scores, no limit.
struct FlashShuffler {
    let cards: [FlashCard]
    private var last: String?

    init(cards: [FlashCard]) {
        self.cards = cards
    }

    mutating func next() -> FlashCard? {
        guard !cards.isEmpty else { return nil }
        var card = cards.randomElement()!
        if cards.count > 1 {
            while card.japanese == last { card = cards.randomElement()! }
        }
        last = card.japanese
        return card
    }
}

/// A flash card that flips (3D) between its Japanese and English sides.
struct FlashCardView: View {
    let card: FlashCard
    let direction: FlashDirection
    let isFlipped: Bool
    /// 1 on iPhone/iPad, smaller on the watch.
    var scale: CGFloat = 1

    private var frontIsJapanese: Bool { direction == .japaneseFirst }

    var body: some View {
        ZStack {
            face(japanese: frontIsJapanese)
                .opacity(isFlipped ? 0 : 1)
            face(japanese: !frontIsJapanese)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(duration: 0.45), value: isFlipped)
    }

    private func face(japanese: Bool) -> some View {
        VStack(spacing: 8 * scale) {
            if japanese {
                Text(card.japanese)
                    .font(.handwriting(size: (card.japanese.count > 1 ? 90 : 130) * scale))
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
            } else {
                Text(card.english)
                    .font(.system(size: 44 * scale, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.4)
                if let detail = card.detail {
                    Text(detail)
                        .font(.system(size: 22 * scale, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .padding(16 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24 * scale)
                .fill(japanese ? Color.orange.opacity(0.15) : Color.blue.opacity(0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24 * scale)
                .strokeBorder(japanese ? Color.orange.opacity(0.6) : Color.blue.opacity(0.5), lineWidth: 2)
        )
    }
}
