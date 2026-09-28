import SwiftUI

/// A flash-card session: random cards from one deck, tap to flip, Next (or swipe left) for another.
/// No scores and no end: she practises as long as she likes.
struct FlashCardSessionView: View {
    let deck: FlashDeck
    let kanji: KanjiLibrary

    @Environment(\.dismiss) private var dismiss
    @AppStorage("flashDirection") private var direction = FlashDirection.japaneseFirst
    @State private var shuffler: FlashShuffler?
    @State private var card: FlashCard?
    @State private var isFlipped = false
    @State private var count = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Direction", selection: $direction) {
                    ForEach(FlashDirection.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)
                .onChange(of: direction) { isFlipped = false }

                if let card {
                    FlashCardView(card: card, direction: direction, isFlipped: isFlipped)
                        .aspectRatio(0.8, contentMode: .fit)
                        .frame(maxWidth: 420, maxHeight: 520)
                        .id(card.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                        .contentShape(Rectangle())
                        .onTapGesture { flip() }
                        .gesture(
                            DragGesture(minimumDistance: 30).onEnded { value in
                                if value.translation.width < -60 { next() }
                            }
                        )
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Tap to turn the card over")
                } else {
                    ContentUnavailableView("No cards", systemImage: "rectangle.on.rectangle.slash")
                }

                Text(isFlipped ? "Swipe left or tap Next for another card" : "Tap the card to turn it over")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Button("Say it", systemImage: "speaker.wave.2.fill") {
                        if let card { Pronouncer.shared.speak(card.speech) }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .font(.title2)

                    Button(isFlipped ? "Hide" : "Turn over", systemImage: "arrow.left.arrow.right") { flip() }
                        .buttonStyle(.bordered)
                        .font(.title3)

                    Button("Next", systemImage: "arrow.right") { next() }
                        .buttonStyle(.borderedProminent)
                        .font(.title3)
                }

                Text("\(count) cards")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("🃏 \(deck.title)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            shuffler = FlashShuffler(cards: deck.cards(kanji: kanji))
            next()
        }
    }

    private func flip() {
        isFlipped.toggle()
        // Hear the Japanese when it appears (front in 日本語 → English, back in English → 日本語).
        let showsJapanese = (direction == .japaneseFirst) != isFlipped
        if showsJapanese, let card { Pronouncer.shared.speak(card.speech) }
    }

    private func next() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFlipped = false
            card = shuffler?.next()
            count += 1
        }
    }
}
