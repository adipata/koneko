import SwiftUI

/// Flash-card menu on the watch: mode and direction, then one of her sets, an alphabet, or a
/// kanji grade.
struct WatchFlashMenuView: View {
    let store: WatchStore
    @AppStorage("flashDirection") private var direction = FlashDirection.japaneseFirst
    @AppStorage("flashMode") private var mode = FlashMode.review

    /// Her sets (which can mix hiragana, katakana and kanji), synced from the iPhone/iPad/Mac.
    private var sets: [FlashSet] { store.snapshot?.flashSets ?? [] }

    /// Why Review isn't available yet (sessions then use Free practice).
    private var reviewHint: String {
        store.reviews == nil
            ? "Review needs her progress: open Koneko on the iPhone or iPad with Settings → Apple Watch sync on, then tap Refresh on the watch's main screen. Until then, cards are Free practice."
            : "Review mode is off in Koneko's Settings on the iPhone or iPad. Until it's on, cards are Free practice."
    }

    var body: some View {
        List {
            Section {
                Picker("Mode", selection: $mode) {
                    ForEach(FlashMode.allCases) { Text($0.title).tag($0) }
                }
                Picker("Show first", selection: $direction) {
                    ForEach(FlashDirection.allCases) { Text($0.title).tag($0) }
                }
            } footer: {
                if mode == .review, !store.canReview {
                    Text(reviewHint)
                }
            }
            if !sets.isEmpty {
                Section("My sets") {
                    ForEach(sets) { set in
                        NavigationLink(value: WatchRoute.flash(.custom(set))) {
                            HStack {
                                Label(set.name, systemImage: "star.fill")
                                Spacer()
                                Text("\(set.symbols.count)").foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            ForEach(KanaScript.allCases) { script in
                Section(script.title) {
                    NavigationLink(value: WatchRoute.flash(.kana(script))) {
                        Label("All \(script.title.lowercased())", systemImage: "rectangle.on.rectangle.angled")
                    }
                }
            }
            Section("Kanji") {
                ForEach(1...7, id: \.self) { grade in
                    NavigationLink(value: WatchRoute.flash(.kanji(grade: grade))) {
                        Text(grade == 7 ? "All · Secondary school" : "All · Grade \(grade)")
                    }
                }
            }
        }
        .navigationTitle("Flash cards")
    }
}

/// A flash-card session on the watch, tap to flip.
/// - Review: the cards that are due plus a few new ones, with the progress from the
///   iPhone/iPad/Mac. After turning a card over she answers 🌱 Not yet or 😺 I knew it; the
///   answers go back to the phone.
/// - Free practice: random cards forever; turn the Digital Crown (or tap Next) for another card.
struct WatchFlashSessionView: View {
    let deck: FlashDeck
    let kanji: KanjiLibrary
    let store: WatchStore

    @AppStorage("flashDirection") private var direction = FlashDirection.japaneseFirst
    @AppStorage("flashMode") private var chosenMode = FlashMode.review
    @State private var cards: [FlashCard] = []
    @State private var shuffler: FlashShuffler?
    @State private var dealer: ReviewDealer?
    @State private var card: FlashCard?
    @State private var isFlipped = false
    /// Review: there was nothing to review when the session started.
    @State private var nothingDue = false
    @State private var crown = 0.0
    @State private var lastCrownStep = 0.0

    private var mode: FlashMode { store.canReview ? chosenMode : .practice }
    private var isReviewing: Bool { mode == .review }

    var body: some View {
        Group {
            if let card {
                FlashCardView(card: card, direction: direction, isFlipped: isFlipped, scale: 0.42)
                    .id(card.id)
                    .transition(.opacity)
                    .contentShape(Rectangle())
                    .onTapGesture { flip() }
            } else if isReviewing, !cards.isEmpty {
                WatchReviewDoneView(
                    nothingDue: nothingDue,
                    garden: store.reviewStates.garden(cards.map { $0.reviewKey(direction) })
                ) { chosenMode = .practice }
            } else {
                Text("No cards")
            }
        }
        .padding(.horizontal, 2)
        // Without a card (end of Review), the crown scrolls the end screen instead.
        .focusable(card != nil)
        .digitalCrownRotation($crown, from: -100_000, through: 100_000, by: 1, sensitivity: .low, isContinuous: true)
        .onChange(of: crown) { _, value in
            // One "click" of the crown (either way) = next card. In Review she answers instead.
            if abs(value - lastCrownStep) >= 1 {
                lastCrownStep = value.rounded()
                if !isReviewing { next() }
            }
        }
        .navigationTitle(deck.title)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                if card != nil {
                    if isReviewing, isFlipped {
                        Button { answer(.notYet) } label: { Text("🌱") }
                            .accessibilityLabel("Not yet")
                        Spacer()
                        speakButton
                        Spacer()
                        Button { answer(.knewIt) } label: { Text("😺") }
                            .accessibilityLabel("I knew it")
                    } else {
                        speakButton
                        Spacer()
                        if isReviewing {
                            Button { flip() } label: { Image(systemName: "arrow.left.arrow.right") }
                                .accessibilityLabel("Turn over")
                        } else {
                            Button { next() } label: { Image(systemName: "arrow.right") }
                                .accessibilityLabel("Next card")
                        }
                    }
                }
            }
        }
        .task(id: mode) { start() }
    }

    private var speakButton: some View {
        Button {
            if let card { Pronouncer.shared.speak(card.speech) }
        } label: {
            Image(systemName: "speaker.wave.2.fill")
        }
        .accessibilityLabel("Say it")
    }

    private func start() {
        cards = deck.cards(kanji: kanji)
        isFlipped = false
        if isReviewing {
            let states = store.reviewStates
            let keys = cards.map { $0.reviewKey(direction) }
            let newLimit = store.newCardsPerDay - states.introducedToday(keys)
            let dealer = ReviewDealer(cards: cards, direction: direction, states: states, newLimit: newLimit)
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
    }

    private func answer(_ rating: ReviewRating) {
        guard let card else { return }
        store.record(rating, for: card.reviewKey(direction))
        dealer?.answered(card, rating)
        next()
    }

    private func next() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isFlipped = false
            card = isReviewing ? dealer?.next() : shuffler?.next()
        }
    }
}

/// End of a Review session on the watch: her garden, and a way to keep playing.
private struct WatchReviewDoneView: View {
    /// Nothing was due when the session started (rather than she finished them all).
    let nothingDue: Bool
    let garden: Garden
    let keepPractising: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text(nothingDue ? "🌸" : "🎉")
                    .font(.system(size: 40))
                Text(nothingDue ? "Nothing to review right now" : "All done for today!")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    ForEach(GardenStage.allCases, id: \.self) { stage in
                        Text("\(stage.emoji) \(garden.count(stage))")
                            .accessibilityLabel("\(stage.title): \(garden.count(stage))")
                    }
                }
                .font(.footnote)
                .monospacedDigit()
                Button("Keep practising", systemImage: "shuffle", action: keepPractising)
            }
        }
    }
}
