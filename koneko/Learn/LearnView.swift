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
    /// The section whose content is on screen. Follows `part` a moment later, so the
    /// picker's slide starts before the heavy chart rebuild blocks the main thread.
    @State private var shownPart: Part?
    private var displayedPart: Part { shownPart ?? part }
    /// Shared by both charts, so switching script keeps the same sound selected.
    @State private var selectedKana: KanaCell?
    /// Same key as the grade buttons in the kanji browser, so flash cards use the chosen grade.
    @AppStorage("learnKanjiGrade") private var kanjiGrade = 1
    @State private var showFlashSets = false
    /// Select mode: ticking symbols for a flash-card set (like selecting photos).
    @State private var picking: SymbolSelection?
    @State private var showNamePrompt = false
    @State private var newSetName = ""

    private var currentKind: FlashSetKind {
        switch part {
        case .hiragana: .hiragana
        case .katakana: .katakana
        case .kanji: .kanji
        }
    }

    // MARK: Sets

    /// Opens Select mode for a set (nil = new set). Editing a set opens the chart of its
    /// first kind if the current one isn't in it.
    private func startPicking(for set: FlashSet?) {
        if let set {
            if !set.kinds.contains(currentKind), let first = set.kinds.first {
                part = first == .hiragana ? .hiragana : first == .katakana ? .katakana : .kanji
            }
            picking = SymbolSelection(items: Set(set.symbols), editingSetID: set.id)
        } else {
            picking = SymbolSelection()
        }
    }

    private func saveSelection() {
        guard let picking else { return }
        if let id = picking.editingSetID {
            model.flashSets.setSymbols(orderedSymbols(picking), of: id)
            self.picking = nil
        } else {
            newSetName = ""
            showNamePrompt = true
        }
    }

    private func saveNewSet() {
        guard let picking else { return }
        model.flashSets.add(name: newSetName, symbols: orderedSymbols(picking))
        self.picking = nil
        showFlashSets = true
    }

    /// Symbols in chart / grade order (hiragana, then katakana, then kanji), not in tapping order.
    private func orderedSymbols(_ picking: SymbolSelection) -> [FlashSymbol] {
        let kana = KanaChart.allCells.map(\.id)
        let hiragana = kana.map { FlashSymbol(kind: .hiragana, value: $0) }
        let katakana = kana.map { FlashSymbol(kind: .katakana, value: $0) }
        let kanji = model.kanji.all.map { FlashSymbol(kind: .kanji, value: $0.character) }
        return (hiragana + katakana + kanji).filter { picking.items.contains($0) }
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
                .task(id: part) {
                    try? await Task.sleep(for: .milliseconds(50))
                    guard !Task.isCancelled else { return }
                    shownPart = part
                }

                if picking != nil {
                    Text("A set can mix hiragana, katakana and kanji: switch above to tick more.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                switch displayedPart {
                case .hiragana, .katakana:
                    KanaStudyView(
                        model: model,
                        script: displayedPart == .katakana ? .katakana : .hiragana,
                        selection: $selectedKana,
                        picking: $picking
                    ) { script in
                        part = script == .hiragana ? .hiragana : .katakana
                    }
                case .kanji:
                    KanjiBrowserView(model: model, picking: $picking)
                }
            }
            .navigationTitle("Learn")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if picking == nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Select", systemImage: "checkmark.circle") {
                            picking = SymbolSelection()
                        }
                        .help("Select symbols for a flash-card set")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Flash cards", systemImage: "rectangle.on.rectangle.angled") {
                            showFlashSets = true
                        }
                        .labelStyle(.titleAndIcon)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let picking {
                    SelectionBar(
                        count: picking.items.count,
                        detail: picking.summary,
                        isEditing: picking.editingSetID != nil,
                        cancel: { self.picking = nil },
                        clear: { self.picking?.items.removeAll() },
                        save: saveSelection
                    )
                }
            }
            .sheet(isPresented: $showFlashSets) {
                FlashSetsView(
                    kanjiGrade: kanjiGrade,
                    store: model.flashSets,
                    kanji: model.kanji
                ) { set in
                    startPicking(for: set)
                }
            }
            .alert("Name this set", isPresented: $showNamePrompt) {
                TextField("e.g. か row, Numbers", text: $newSetName)
                Button("Cancel", role: .cancel) {}
                Button("Save") { saveNewSet() }
            } message: {
                Text(picking?.summary ?? "")
            }
        }
    }
}
