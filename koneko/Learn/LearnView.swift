import SwiftUI

/// Learn section: hiragana and katakana charts, and kanji by school grade.
struct LearnView: View {
    let model: AppModel

    enum Part: String, CaseIterable, Identifiable {
        case hiragana, katakana, kanji
        var id: String { rawValue }
        var title: String {
            switch self {
            case .hiragana: "あ Hiragana"
            case .katakana: "ア Katakana"
            case .kanji: "字 Kanji"
            }
        }
    }

    @AppStorage("learnPart") private var part = Part.hiragana
    /// Shared by both charts, so switching script keeps the same sound selected.
    @State private var selectedKana: KanaCell?
    /// Same key as the grade buttons in the kanji browser, so flash cards use the chosen grade.
    @AppStorage("learnKanjiGrade") private var kanjiGrade = 1
    @State private var flashDeck: FlashDeck?

    private var currentDeck: FlashDeck {
        switch part {
        case .hiragana: .kana(.hiragana)
        case .katakana: .kana(.katakana)
        case .kanji: .kanji(grade: kanjiGrade)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Learn", selection: $part) {
                    ForEach(Part.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 480)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch part {
                case .hiragana, .katakana:
                    KanaStudyView(
                        model: model,
                        script: part == .katakana ? .katakana : .hiragana,
                        selection: $selectedKana
                    ) { script in
                        part = script == .hiragana ? .hiragana : .katakana
                    }
                case .kanji:
                    KanjiBrowserView(model: model)
                }
            }
            .navigationTitle("Learn")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Flash cards", systemImage: "rectangle.on.rectangle.angled") {
                        flashDeck = currentDeck
                    }
                    .labelStyle(.titleAndIcon)
                    .help("Practise \(currentDeck.title) with flash cards")
                }
            }
            .sheet(item: $flashDeck) { deck in
                FlashCardSessionView(deck: deck, kanji: model.kanji)
                    #if os(macOS)
                    .frame(minWidth: 480, minHeight: 640)
                    #endif
            }
        }
    }
}
