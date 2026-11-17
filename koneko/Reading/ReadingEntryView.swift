#if os(iOS)
import SwiftUI

/// One scanned part: the Japanese text (selectable, to copy parts of it) and the AI's
/// explanation saved with it.
struct ReadingEntryContent: View {
    let entry: ReadingEntry
    /// My words, to save words and kanji from the explanation.
    let history: HistoryStore
    var onLookUp: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                SelectableText(text: entry.text, textStyle: .title2, weight: .medium, onLookUp: onLookUp)
                HStack(spacing: 10) {
                    CopyButton(text: entry.text)
                    if !entry.explanation.kana.isEmpty {
                        Button("Listen", systemImage: "speaker.wave.2.fill") {
                            // The kana reading, so kanji are never misread.
                            Pronouncer.shared.speak(entry.explanation.kana)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.08)))

            let explanation = entry.explanation
            if !explanation.kana.isEmpty {
                section("In kana", systemImage: "character.textbox") {
                    SelectableText(text: explanation.kana, textStyle: .title3, onLookUp: onLookUp)
                }
            }
            if !explanation.translation.isEmpty {
                section("Meaning", systemImage: "globe") {
                    SelectableText(text: explanation.translation, textStyle: .body)
                }
            }
            if !explanation.explanation.isEmpty {
                section("How it works", systemImage: "lightbulb") {
                    SelectableText(text: explanation.explanation, textStyle: .body, onLookUp: onLookUp)
                }
            }
            if !explanation.words.isEmpty {
                section("Words", systemImage: "list.bullet") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(explanation.words.enumerated()), id: \.offset) { _, word in
                            pieceRow(word.japanese, reading: word.reading, meaning: word.meaning, note: word.note, large: false)
                        }
                    }
                }
            }
            if !explanation.kanji.isEmpty {
                section("Kanji", systemImage: "character.book.closed") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(explanation.kanji.enumerated()), id: \.offset) { _, kanji in
                            pieceRow(kanji.kanji, reading: kanji.reading, meaning: kanji.meaning, note: kanji.note, large: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 640, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private func section(_ title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.orange)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pieceRow(_ japanese: String, reading: String, meaning: String, note: String, large: Bool) -> some View {
        let word = Self.word(japanese, reading: reading, meaning: meaning)
        // Japanese and its reading on top (the reading wraps below as a whole if needed), then
        // the English, then the note, so nothing gets interleaved when lines wrap.
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                FlowLayout(spacing: 8, lineSpacing: 2, centered: false) {
                    Text(japanese)
                        .font(large ? .largeTitle : .title3.weight(.medium))
                    if !reading.isEmpty, reading != japanese {
                        Text(reading)
                            .foregroundStyle(.secondary)
                    }
                }
                if !meaning.isEmpty {
                    Text(meaning)
                }
                if !note.isEmpty {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                if let spoken = Self.spokenText(japanese, reading: reading) {
                    listenButton(spoken, label: japanese)
                }
                if let word {
                    saveButton(word)
                }
            }
        }
        .contextMenu {
            if let word, !isSaved(word) {
                Button("Save to My words", systemImage: "plus.circle") { history.record(word) }
            }
            Button("Copy “\(japanese)”", systemImage: "doc.on.doc") { Clipboard.copy(japanese) }
            if let onLookUp {
                Button("Look up in Write", systemImage: "pencil.and.scribble") { onLookUp(japanese) }
            }
        }
    }

    private func listenButton(_ spoken: String, label: String) -> some View {
        Button {
            Pronouncer.shared.speak(spoken)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.title3)
        }
        .buttonStyle(.borderless)
        .tint(.orange)
        .accessibilityLabel("Listen to \(label)")
        .help("Listen")
    }

    /// What to say for a word or kanji: its kana reading, so kanji are never misread.
    private static func spokenText(_ japanese: String, reading: String) -> String? {
        let reading = reading.trimmingCharacters(in: .whitespacesAndNewlines)
        if JapaneseText.isKana(reading) { return reading }
        return JapaneseText.isKana(japanese) ? japanese : nil
    }

    private func saveButton(_ word: WordCandidate) -> some View {
        let saved = isSaved(word)
        return Button {
            history.record(word)
        } label: {
            Image(systemName: saved ? "checkmark.circle.fill" : "plus.circle")
                .font(.title3)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .tint(saved ? .green : .orange)
        .disabled(saved)
        .accessibilityLabel(saved ? "\(word.japanese) is in My words" : "Save \(word.japanese) to My words")
        .help(saved ? "In My words" : "Save to My words")
    }

    private func isSaved(_ word: WordCandidate) -> Bool {
        history.entries.contains { $0.id == word.id }
    }

    /// A word or kanji of the explanation as a My words entry; nil if it can't be one
    /// (not Japanese, or no kana reading).
    private static func word(_ japanese: String, reading: String, meaning: String) -> WordCandidate? {
        let kana = JapaneseText.isKana(japanese) ? japanese : reading
        let candidate = WordCandidate(
            japanese: japanese,
            reading: kana,
            romaji: "",
            meaning: meaning,
            emoji: "",
            isLoanword: JapaneseText.isKana(japanese) && JapaneseText.katakana(japanese) == japanese,
            parts: [WordCandidate.Part(text: japanese, reading: JapaneseText.hiragana(kana))]
        )
        return candidate.validated()
    }
}

/// A saved part, opened from a reading's history. "Explain again" asks the AI for a new
/// explanation (offered prominently when the saved one is missing).
struct ReadingEntryView: View {
    let readingID: Reading.ID
    let entryID: ReadingEntry.ID
    let store: ReadingStore
    let history: HistoryStore
    let model: AIModel
    let openSettings: () -> Void
    var onLookUp: ((String) -> Void)?

    @State private var explaining: Task<Void, Never>?
    @State private var problem: AIProblem?

    private var reading: Reading? { store.reading(readingID) }
    private var entry: ReadingEntry? { reading?.entries.first { $0.id == entryID } }

    var body: some View {
        if let entry {
            ScrollView {
                VStack(spacing: 20) {
                    ReadingEntryContent(entry: entry, history: history, onLookUp: onLookUp)
                    if entry.explanation.isEmpty || explaining != nil || problem != nil {
                        explainAgainBox(missing: entry.explanation.isEmpty)
                    }
                }
                .padding()
            }
            .navigationTitle(entry.date.formatted(date: .abbreviated, time: .shortened))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Explain again", systemImage: "arrow.clockwise", action: explainAgain)
                        .disabled(explaining != nil)
                }
            }
            .onDisappear { explaining?.cancel() }
        } else {
            ContentUnavailableView("This part was deleted", systemImage: "text.viewfinder")
        }
    }

    @ViewBuilder
    private func explainAgainBox(missing: Bool) -> some View {
        VStack(spacing: 10) {
            if explaining != nil {
                ProgressView("Explaining…")
            } else if let problem {
                AIProblemView(problem: problem, retry: explainAgain, openSettings: openSettings)
            } else if missing {
                Text("The explanation for this part is missing.")
                    .foregroundStyle(.secondary)
                Button("Explain again", systemImage: "sparkles", action: explainAgain)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.08)))
    }

    private func explainAgain() {
        guard explaining == nil, let reading, let entry else { return }
        problem = nil
        explaining = Task {
            defer { explaining = nil }
            do {
                let explanation = try await ReadingExplainer.explainAgain(entry, in: reading, model: model)
                store.setExplanation(explanation, of: entryID, in: readingID)
            } catch is CancellationError {
                return
            } catch {
                problem = AIProblem(error, provider: model.provider)
            }
        }
    }
}
#endif
