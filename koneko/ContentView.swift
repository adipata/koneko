import SwiftUI

struct ContentView: View {
    @State private var library = StrokeLibrary()
    @State private var input = "ねこ"
    @State private var selectedIndex = 0
    @State private var showCredits = false

    private static let sampleWords = ["ねこ", "猫", "いぬ", "学校", "ありがとう", "カタカナ", "日本"]

    private var characters: [Character] {
        Array(input.filter { !$0.isWhitespace })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    inputSection

                    switch library.loadState {
                    case .loading:
                        ProgressView("Loading strokes…")
                            .padding(.top, 40)
                    case .failed(let message):
                        ContentUnavailableView(
                            "Couldn't load stroke data",
                            systemImage: "exclamationmark.triangle",
                            description: Text(message)
                        )
                    case .ready:
                        wordSection
                    }
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Koneko 🐱")
            .toolbar {
                Button("Credits", systemImage: "info.circle") { showCredits = true }
            }
            .sheet(isPresented: $showCredits) { CreditsView() }
        }
        .task { await library.load() }
        .onChange(of: input) { selectedIndex = 0 }
    }

    // MARK: Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Type a Japanese word, e.g. ねこ or 猫", text: $input)
                .font(.title2)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Self.sampleWords, id: \.self) { word in
                        Button(word) { input = word }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    // MARK: Word and strokes

    @ViewBuilder
    private var wordSection: some View {
        if characters.isEmpty {
            ContentUnavailableView(
                "Type a word",
                systemImage: "pencil.and.scribble",
                description: Text("Then tap a character to see how it's written.")
            )
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                        characterTile(character, index: index)
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

    private func characterTile(_ character: Character, index: Int) -> some View {
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
    }
}

#Preview {
    ContentView()
}
