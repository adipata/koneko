import SwiftUI

/// Flash-card menu on the watch: direction, then an alphabet or a kanji grade.
struct WatchFlashMenuView: View {
    @AppStorage("flashDirection") private var direction = FlashDirection.japaneseFirst

    var body: some View {
        List {
            Section {
                Picker("Show first", selection: $direction) {
                    ForEach(FlashDirection.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Alphabets") {
                ForEach(KanaScript.allCases) { script in
                    NavigationLink(value: WatchRoute.flash(.kana(script))) {
                        Label(script.title, systemImage: "rectangle.on.rectangle.angled")
                    }
                }
            }
            Section("Kanji") {
                ForEach(1...7, id: \.self) { grade in
                    NavigationLink(value: WatchRoute.flash(.kanji(grade: grade))) {
                        Text(grade == 7 ? "Secondary school" : "Grade \(grade)")
                    }
                }
            }
        }
        .navigationTitle("Flash cards")
    }
}

/// Random cards forever: tap to flip, turn the Digital Crown (or tap Next) for another card.
struct WatchFlashSessionView: View {
    let deck: FlashDeck
    let kanji: KanjiLibrary

    @AppStorage("flashDirection") private var direction = FlashDirection.japaneseFirst
    @State private var shuffler: FlashShuffler?
    @State private var card: FlashCard?
    @State private var isFlipped = false
    @State private var crown = 0.0
    @State private var lastCrownStep = 0.0

    var body: some View {
        Group {
            if let card {
                FlashCardView(card: card, direction: direction, isFlipped: isFlipped, scale: 0.42)
                    .id(card.id)
                    .transition(.opacity)
                    .contentShape(Rectangle())
                    .onTapGesture { flip() }
            } else {
                Text("No cards")
            }
        }
        .padding(.horizontal, 2)
        .focusable()
        .digitalCrownRotation($crown, from: -100_000, through: 100_000, by: 1, sensitivity: .low, isContinuous: true)
        .onChange(of: crown) { _, value in
            // One "click" of the crown (either way) = next card.
            if abs(value - lastCrownStep) >= 1 {
                lastCrownStep = value.rounded()
                next()
            }
        }
        .navigationTitle(deck.title)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    if let card { Pronouncer.shared.speak(card.speech) }
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .accessibilityLabel("Say it")
                Spacer()
                Button {
                    next()
                } label: {
                    Image(systemName: "arrow.right")
                }
                .accessibilityLabel("Next card")
            }
        }
        .task {
            shuffler = FlashShuffler(cards: deck.cards(kanji: kanji))
            next()
        }
    }

    private func flip() {
        isFlipped.toggle()
    }

    private func next() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isFlipped = false
            card = shuffler?.next()
        }
    }
}
