import SwiftUI

/// The characters of a word as tappable tiles, with the stroke animation for the selected one.
struct WordStrokesView: View {
    let word: WordCandidate
    let library: StrokeLibrary
    /// Say a character's sound when its tile is tapped.
    var speaksOnTap = true
    /// Called with the stars (1–3) when she finishes writing a character in Practice.
    var onPracticeFinished: ((Character, Int) -> Void)?

    @State private var selectedIndex = 0
    @AppStorage("strokeMode") private var mode = Mode.watch

    enum Mode: String {
        case watch
        case practice
    }

    private var characters: [Character] {
        Array(word.japanese.filter { !$0.isWhitespace })
    }

    var body: some View {
        if characters.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 20) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                            tile(character, index: index)
                        }
                    }
                    .padding(.vertical, 4)
                }

                let index = min(selectedIndex, characters.count - 1)
                let character = characters[index]
                if let data = library.strokes(for: character) {
                    Picker("Mode", selection: $mode) {
                        Label("Watch", systemImage: "play.circle").tag(Mode.watch)
                        Label("Practice", systemImage: "pencil.tip").tag(Mode.practice)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)

                    switch mode {
                    case .watch:
                        StrokeOrderView(data: data)
                            .id("watch-\(index)-\(character)")
                    case .practice:
                        TracingView(data: data) { stars in
                            onPracticeFinished?(character, stars)
                        }
                            .id("practice-\(index)-\(character)")
                    }
                } else {
                    ContentUnavailableView(
                        "No stroke order for “\(String(character))”",
                        systemImage: "questionmark.square.dashed",
                        description: Text("Stroke data covers hiragana, katakana and kanji.")
                    )
                }
            }
        }
    }

    private func tile(_ character: Character, index: Int) -> some View {
        let isSelected = index == min(selectedIndex, characters.count - 1)
        let hasStrokes = library.strokes(for: character) != nil
        return Button {
            selectedIndex = index
            if speaksOnTap, let sound = spokenText(forTileAt: index) {
                Pronouncer.shared.speak(sound)
            }
        } label: {
            Text(String(character))
                .font(.handwriting(size: 46))
                .frame(width: 72, height: 72)
                .foregroundStyle(hasStrokes ? Color.primary : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.orange.opacity(0.2) : Color.secondary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 3)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Character \(String(character))")
    }

    /// Tiles skip whitespace, so map the tile index back to the index in `word.japanese`.
    private func spokenText(forTileAt tileIndex: Int) -> String? {
        var tile = 0
        for (index, character) in word.japanese.enumerated() where !character.isWhitespace {
            if tile == tileIndex { return word.spokenText(forCharacterAt: index) }
            tile += 1
        }
        return nil
    }
}
