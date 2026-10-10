import SwiftUI

/// Hiragana or katakana: the chart, a box to type a character, and the selected sound.
struct KanaStudyView: View {
    let model: AppModel
    let script: KanaScript
    @Binding var selection: KanaCell?
    /// Select mode (choosing symbols for a flash-card set), or nil.
    @Binding var picking: SymbolSelection?
    /// Called when she types a character of the other script.
    let switchScript: (KanaScript) -> Void

    @State private var typed = ""
    @State private var notFound = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        StudySplit(selection: $selection, placeholder: "Choose a character") {
            VStack(alignment: .leading, spacing: 20) {
                findField
                ForEach(KanaChart.sections) { section in
                    KanaChartView(section: section, script: script, selection: $selection, picking: $picking) { cell in
                        Pronouncer.shared.speak(cell.hiragana)
                    }
                }
            }
        } detail: { cell in
            KanaDetailView(model: model, cell: cell, script: script, switchScript: switchScript)
        }
    }

    private var findField: some View {
        SearchField(prompt: "Type \(script.text("か")) or ka", text: $typed, focus: $fieldFocused, onSubmit: find)
        .onChange(of: typed) { notFound = false }
        .overlay(alignment: .bottomLeading) {
            if notFound {
                Text("No character “\(typed)”")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .offset(y: 18)
            }
        }
        .frame(maxWidth: 420)
    }

    /// Runs when she presses Return/Search: opens the character, then clears the box and
    /// hides the keyboard so the chart and the tabs are visible again.
    private func find() {
        guard let cell = KanaChart.find(typed) else {
            notFound = !typed.trimmingCharacters(in: .whitespaces).isEmpty
            return
        }
        defer {
            typed = ""
            fieldFocused = false
        }
        // Typed katakana on the hiragana chart (or the other way round): switch charts.
        if let first = typed.unicodeScalars.first {
            if JapaneseText.isKatakana(first), script == .hiragana { switchScript(.katakana) }
            if JapaneseText.isHiragana(first), script == .katakana { switchScript(.hiragana) }
        }
        if selection != cell {
            selection = cell
            Pronouncer.shared.speak(cell.hiragana)
        }
    }
}

/// One section of the chart as a grid with column (a i u e o) and row (k s t…) labels.
struct KanaChartView: View {
    let section: KanaSection
    let script: KanaScript
    @Binding var selection: KanaCell?
    @Binding var picking: SymbolSelection?
    let onTap: (KanaCell) -> Void

    private var isPicking: Bool { picking != nil }
    private var kind: FlashSetKind { script == .katakana ? .katakana : .hiragana }
    private var allIDs: [String] { section.rows.flatMap { $0.cells.compactMap { $0?.id } } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(section.title)
                    .font(.headline)
                Spacer()
                if isPicking {
                    let allChecked = picking?.containsAll(kind, allIDs) == true
                    Button(allChecked ? "Deselect all" : "Select all") { picking?.toggleAll(kind, allIDs) }
                        .font(.subheadline)
                }
            }
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    Color.clear.frame(width: 28, height: 1)
                    ForEach(Array(section.columns.enumerated()), id: \.offset) { index, column in
                        // In Select mode, tapping a column letter (a, i, u…) ticks the whole column.
                        Button {
                            picking?.toggleAll(kind, section.rows.compactMap { $0.cells.indices.contains(index) ? $0.cells[index]?.id : nil })
                        } label: {
                            Text(column)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isPicking ? Color.accentColor : .secondary)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isPicking)
                    }
                }
                ForEach(section.rows) { row in
                    GridRow {
                        // In Select mode, tapping a row letter (k, s, t…) ticks the whole row.
                        Button {
                            picking?.toggleAll(kind, row.cells.compactMap { $0?.id })
                        } label: {
                            Text(row.label.isEmpty ? "·" : row.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isPicking ? Color.accentColor : .secondary)
                                .frame(width: 28, height: 40)
                        }
                        .buttonStyle(.plain)
                        .disabled(!isPicking)
                        ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                            if let cell {
                                tile(cell)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity, minHeight: 56)
                            }
                        }
                    }
                }
            }
        }
    }

    private func tile(_ cell: KanaCell) -> some View {
        let isSelected = !isPicking && selection == cell
        let isChecked = picking?.contains(kind, cell.id) == true
        return Button {
            if isPicking {
                picking?.toggle(kind, cell.id)
            } else {
                selection = cell
                onTap(cell)
            }
        } label: {
            VStack(spacing: 0) {
                Text(script.text(cell.hiragana))
                    .font(.handwriting(size: 28))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(cell.romaji)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.orange.opacity(0.25) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .bottomTrailing) {
                if isPicking { SelectionCheckmark(isChecked: isChecked) }
            }
            .opacity(isPicking && !isChecked ? 0.75 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(script.text(cell.hiragana)), \(cell.romaji)")
    }
}

/// The selected sound: how it's written (stroke order / practice), its sound, and the
/// same sound in the other script.
struct KanaDetailView: View {
    let model: AppModel
    let cell: KanaCell
    let script: KanaScript
    let switchScript: (KanaScript) -> Void

    private var text: String { script.text(cell.hiragana) }
    private var other: KanaScript { script == .hiragana ? .katakana : .hiragana }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                Text(text)
                    .font(.handwriting(size: 72))
                VStack(alignment: .leading, spacing: 8) {
                    Text(cell.romaji)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    HStack {
                        Button("Say it", systemImage: "speaker.wave.2.fill") {
                            Pronouncer.shared.speak(cell.hiragana)
                        }
                        Button("Say it slowly", systemImage: "tortoise.fill") {
                            Pronouncer.shared.speak(cell.hiragana, slow: true)
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }
            }

            Button {
                switchScript(other)
            } label: {
                Text("In \(other.title): \(other.text(cell.hiragana))")
                    .font(.callout)
            }
            .buttonStyle(.bordered)

            switch model.library.loadState {
            case .ready:
                WordStrokesView(
                    word: .kana(text, romaji: cell.romaji),
                    library: model.library,
                    speaksOnTap: true,
                    showRomaji: true,
                    showsTiles: text.count > 1
                )
            case .loading:
                ProgressView()
            case .failed(let message):
                Text(message).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

extension WordCandidate {
    /// A single kana (or combined sound like きゃ) as a word, for the stroke views.
    static func kana(_ text: String, romaji: String) -> WordCandidate {
        let reading = JapaneseText.hiragana(text)
        return WordCandidate(
            japanese: text, reading: reading, romaji: romaji, meaning: "", emoji: "",
            isLoanword: false, parts: [Part(text: text, reading: reading)]
        )
    }
}
