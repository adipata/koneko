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

    /// Opens Select mode for a set (nil = new set), in the right chart.
    private func startPicking(for set: FlashSet?) {
        if let set {
            part = set.kind == .hiragana ? .hiragana : set.kind == .katakana ? .katakana : .kanji
            picking = SymbolSelection(kind: set.kind, items: Set(set.items), editingSetID: set.id)
        } else {
            picking = SymbolSelection(kind: currentKind)
        }
    }

    private func saveSelection() {
        guard let picking else { return }
        if let id = picking.editingSetID {
            model.flashSets.setItems(orderedItems(picking), of: id)
            self.picking = nil
        } else {
            newSetName = ""
            showNamePrompt = true
        }
    }

    private func saveNewSet() {
        guard let picking else { return }
        model.flashSets.add(name: newSetName, kind: picking.kind, items: orderedItems(picking))
        self.picking = nil
        showFlashSets = true
    }

    /// Items in chart / grade order, not in tapping order.
    private func orderedItems(_ picking: SymbolSelection) -> [String] {
        switch picking.kind {
        case .hiragana, .katakana:
            KanaChart.allCells.map(\.id).filter(picking.items.contains)
        case .kanji:
            model.kanji.all.map(\.character).filter(picking.items.contains)
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
                .disabled(picking != nil)

                switch part {
                case .hiragana, .katakana:
                    KanaStudyView(
                        model: model,
                        script: part == .katakana ? .katakana : .hiragana,
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
                            picking = SymbolSelection(kind: currentKind)
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
                        isEditing: picking.editingSetID != nil,
                        cancel: { self.picking = nil },
                        clear: { self.picking?.items.removeAll() },
                        save: saveSelection
                    )
                }
            }
            .sheet(isPresented: $showFlashSets) {
                FlashSetsView(
                    kind: currentKind,
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
                Text("\(picking?.items.count ?? 0) symbols")
            }
        }
    }
}
