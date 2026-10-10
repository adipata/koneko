import SwiftUI

/// One word per page; turn the Digital Crown or swipe up/down for the next word.
struct WatchWordPager: View {
    let store: WatchStore
    let entries: [HistoryEntry]
    @State var selection: String

    var body: some View {
        TabView(selection: $selection) {
            ForEach(entries) { entry in
                WatchWordDetailView(
                    word: store.display(entry.word),
                    showRomaji: store.snapshot?.showRomaji ?? true,
                    showFurigana: store.snapshot?.showFurigana ?? true
                )
                .tag(entry.id)
            }
        }
        .tabViewStyle(.verticalPage)
    }
}

/// The word: emoji, Japanese (with furigana), romaji, English, and buttons to hear it.
struct WatchWordDetailView: View {
    let word: WordCandidate
    let showRomaji: Bool
    let showFurigana: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                if !word.emoji.isEmpty {
                    Text(word.emoji).font(.system(size: 34))
                }
                FuriganaText(parts: word.parts, showFurigana: showFurigana, size: 40)
                if showRomaji, !word.romaji.isEmpty {
                    Text(word.romaji)
                        .font(.body)
                        .foregroundStyle(.orange)
                }
                if !word.meaning.isEmpty {
                    Text(word.meaning)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: 10) {
                    Button {
                        Pronouncer.shared.speak(word.spokenText)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .accessibilityLabel("Say it")
                    Button {
                        Pronouncer.shared.speak(word.spokenText, slow: true)
                    } label: {
                        Image(systemName: "tortoise.fill")
                    }
                    .accessibilityLabel("Say it slowly")
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
