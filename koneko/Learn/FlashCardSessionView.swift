import SwiftUI

/// How a flash-card session deals its cards.
enum FlashMode: String, CaseIterable, Identifiable {
    /// Spaced repetition: due cards and a few new ones; she says whether she knew each card.
    case review
    /// Random cards forever, nothing remembered.
    case practice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .review: "🌱 Review"
        case .practice: "🎲 Free practice"
        }
    }
}

/// A flash-card session from one deck, tap to flip.
/// - Review: the cards that are due plus a few new ones; after turning a card over she answers
///   😺 I knew it (or swipe right) or 🌱 Not yet (or swipe left). Her garden shows how her cards grow.
/// - Free practice: random cards with Next (or swipe left), no end and nothing remembered.
struct FlashCardSessionView: View {
    let deck: FlashDeck
    let kanji: KanjiLibrary

    @Environment(\.dismiss) private var dismiss
    @Environment(ReviewStore.self) private var reviews
    @Environment(AppSettings.self) private var settings
    @AppStorage("flashDirection") private var direction = FlashDirection.japaneseFirst
    @AppStorage("flashMode") private var chosenMode = FlashMode.review
    @State private var cards: [FlashCard] = []
    @State private var shuffler: FlashShuffler?
    @State private var dealer: ReviewDealer?
    @State private var card: FlashCard?
    @State private var isFlipped = false
    @State private var count = 0
    /// Review: there was nothing to review when the session started.
    @State private var nothingDue = false

    private var mode: FlashMode { settings.smartReview ? chosenMode : .practice }
    private var isReviewing: Bool { mode == .review }
    /// Restarts the session when the mode or direction changes.
    private var sessionID: String { "\(mode.rawValue)|\(direction.rawValue)" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if settings.smartReview {
                    Picker("Mode", selection: $chosenMode) {
                        ForEach(FlashMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                }

                Picker("Direction", selection: $direction) {
                    ForEach(FlashDirection.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420)

                if isReviewing, !cards.isEmpty {
                    GardenRow(garden: reviews.garden(cards.map { $0.reviewKey(direction) }))
                }

                if let card {
                    FlashCardView(card: card, direction: direction, isFlipped: isFlipped)
                        .aspectRatio(0.8, contentMode: .fit)
                        .frame(maxWidth: 420, maxHeight: 520)
                        .id(count)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                        .contentShape(Rectangle())
                        .onTapGesture { flip() }
                        .gesture(
                            DragGesture(minimumDistance: 30).onEnded { value in
                                swiped(value.translation.width)
                            }
                        )
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Tap to turn the card over")
                } else if isReviewing, !cards.isEmpty {
                    ReviewDoneView(nothingDue: nothingDue) { chosenMode = .practice }
                        .frame(maxWidth: 420, maxHeight: 520)
                } else {
                    ContentUnavailableView("No cards", systemImage: "rectangle.on.rectangle.slash")
                }

                if card != nil {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    buttons
                }

                Text(footer)
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
        .task(id: sessionID) { start() }
    }

    private var buttons: some View {
        HStack(spacing: 16) {
            Button("Say it", systemImage: "speaker.wave.2.fill") {
                if let card { Pronouncer.shared.speak(card.speech) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .font(.title2)

            if isReviewing, isFlipped {
                Button("🌱 Not yet") { answer(.notYet) }
                    .buttonStyle(.bordered)
                    .font(.title3)
                Button("😺 I knew it") { answer(.knewIt) }
                    .buttonStyle(.borderedProminent)
                    .font(.title3)
            } else {
                Button(isFlipped ? "Hide" : "Turn over", systemImage: "arrow.left.arrow.right") { flip() }
                    .buttonStyle(.bordered)
                    .font(.title3)
                if !isReviewing {
                    Button("Next", systemImage: "arrow.right") { next() }
                        .buttonStyle(.borderedProminent)
                        .font(.title3)
                }
            }
        }
    }

    private var hint: String {
        switch (isReviewing, isFlipped) {
        case (_, false): "Tap the card to turn it over"
        case (true, true): "Did you know it? Swipe right for yes, left for not yet"
        case (false, true): "Swipe left or tap Next for another card"
        }
    }

    private var footer: String {
        if isReviewing {
            let left = dealer?.remaining ?? 0
            return card == nil || left == 0 ? "" : "\(left) more"
        }
        return "\(count) cards"
    }

    private func start() {
        cards = deck.cards(kanji: kanji)
        isFlipped = false
        count = 0
        if isReviewing {
            let keys = cards.map { $0.reviewKey(direction) }
            let newLimit = settings.newCardsPerDay - reviews.introducedToday(keys)
            let dealer = ReviewDealer(cards: cards, direction: direction, states: reviews.states, newLimit: newLimit)
            nothingDue = dealer.remaining == 0
            self.dealer = dealer
            shuffler = nil
        } else {
            shuffler = FlashShuffler(cards: cards)
            dealer = nil
        }
        next()
    }

    private func flip() {
        isFlipped.toggle()
        // Hear the Japanese when it appears (front in 日本語 → English, back in English → 日本語).
        let showsJapanese = (direction == .japaneseFirst) != isFlipped
        if showsJapanese, let card { Pronouncer.shared.speak(card.speech) }
    }

    private func swiped(_ width: CGFloat) {
        if isReviewing {
            guard isFlipped else { return }
            if width < -60 {
                answer(.notYet)
            } else if width > 60 {
                answer(.knewIt)
            }
        } else if width < -60 {
            next()
        }
    }

    private func answer(_ rating: ReviewRating) {
        guard let card else { return }
        reviews.record(rating, for: card.reviewKey(direction))
        dealer?.answered(card, rating)
        next()
    }

    private func next() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFlipped = false
            card = isReviewing ? dealer?.next() : shuffler?.next()
            count += 1
        }
    }
}

/// Her garden for the deck: how many cards are sprouts, growing or in bloom, and seeds not met yet.
struct GardenRow: View {
    let garden: Garden

    var body: some View {
        HStack(spacing: 14) {
            ForEach(GardenStage.allCases, id: \.self) { stage in
                Text("\(stage.emoji) \(garden.count(stage))")
                    .accessibilityLabel("\(stage.title): \(garden.count(stage))")
            }
            if garden.seeds > 0 {
                Text("· \(garden.seeds) seeds")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.headline)
        .monospacedDigit()
    }
}

/// End of a Review session, with a way to keep playing.
private struct ReviewDoneView: View {
    /// Nothing was due when the session started (rather than she finished them all).
    let nothingDue: Bool
    let keepPractising: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(nothingDue ? "🌸" : "🎉")
                .font(.system(size: 80))
            Text(nothingDue ? "Nothing to review right now" : "All done for today!")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Your garden grows a little every time you come back. 🌱")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Keep practising", systemImage: "shuffle", action: keepPractising)
                .buttonStyle(.borderedProminent)
                .font(.title3)
        }
        .padding()
    }
}
