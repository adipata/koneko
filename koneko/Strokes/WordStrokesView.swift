import SwiftUI

/// The characters of a word as tappable tiles, with the stroke animation for the selected one.
struct WordStrokesView: View {
    let text: String
    let library: StrokeLibrary

    @State private var selectedIndex = 0

    private var characters: [Character] {
        Array(text.filter { !$0.isWhitespace })
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
                    StrokeOrderView(data: data)
                        .id("\(index)-\(character)")
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
        } label: {
            Text(String(character))
                .font(.system(size: 44))
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
}
