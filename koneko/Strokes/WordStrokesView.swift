import SwiftUI

/// The characters of a word as tappable tiles, with the stroke animation for the selected one.
struct WordStrokesView: View {
    let word: WordCandidate
    let library: StrokeLibrary
    /// Say a character's sound when its tile is tapped.
    var speaksOnTap = true
    var showRomaji = true
    /// Called with the stars (1–3) when she finishes writing a character in Practice.
    var onPracticeFinished: ((Character, Int) -> Void)?

    @State private var selectedIndex = 0
    @AppStorage("strokeMode") private var mode = Mode.watch

    enum Mode: String {
        case watch
        case practice
    }

    private struct Tile {
        let character: Character
        let romaji: String
        /// Position in `word.japanese` (tiles skip spaces).
        let wordIndex: Int
    }

    /// The tiles: every non-space character of the word, with its romaji.
    private var tiles: [Tile] {
        let romaji = word.romajiPerCharacter()
        return word.japanese.enumerated().compactMap { index, character -> Tile? in
            guard !character.isWhitespace else { return nil }
            return Tile(character: character, romaji: romaji.indices.contains(index) ? romaji[index] : "", wordIndex: index)
        }
    }

    private var characters: [Character] {
        tiles.map(\.character)
    }

    var body: some View {
        if characters.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 20) {
                let tiles = self.tiles
                FlowLayout(spacing: 10, lineSpacing: 10) {
                    ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                        tileView(tile.character, romaji: tile.romaji, index: index)
                    }
                }
                .padding(.vertical, 4)

                let index = min(selectedIndex, tiles.count - 1)
                let character = tiles[index].character
                selectedHeader(character, romaji: tiles[index].romaji, wordIndex: tiles[index].wordIndex)

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

    /// The selected character, big, with its romaji and a speaker button.
    private func selectedHeader(_ character: Character, romaji: String, wordIndex: Int) -> some View {
        HStack(spacing: 16) {
            Text(String(character))
                .font(.handwriting(size: 44))
            if showRomaji, !romaji.isEmpty {
                Text(romaji)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
            }
            if let sound = word.spokenText(forCharacterAt: wordIndex) {
                Button("Say it", systemImage: "speaker.wave.2.fill") {
                    Pronouncer.shared.speak(sound)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
            }
        }
    }

    private func tileView(_ character: Character, romaji: String, index: Int) -> some View {
        let isSelected = index == min(selectedIndex, characters.count - 1)
        let hasStrokes = library.strokes(for: character) != nil
        return Button {
            selectedIndex = index
            if speaksOnTap, let sound = spokenText(forTileAt: index) {
                Pronouncer.shared.speak(sound)
            }
        } label: {
            VStack(spacing: 0) {
                Text(String(character))
                    .font(.handwriting(size: 46))
                if showRomaji {
                    Text(romaji.isEmpty ? " " : romaji)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(width: 72, height: showRomaji ? 90 : 72)
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
        let tiles = self.tiles
        guard tiles.indices.contains(tileIndex) else { return nil }
        return word.spokenText(forCharacterAt: tiles[tileIndex].wordIndex)
    }
}
