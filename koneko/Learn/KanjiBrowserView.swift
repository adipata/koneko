import SwiftUI

/// Kanji by school grade (like the "Kanji she knows" setting), with search.
struct KanjiBrowserView: View {
    let model: AppModel
    /// Select mode (choosing kanji for a flash-card set), or nil.
    @Binding var picking: SymbolSelection?

    @AppStorage("learnKanjiGrade") private var grade = 1
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var selection: KanjiInfo?
    @State private var results: [KanjiInfo] = []
    /// The text `results` were found for (they arrive a moment after typing).
    @State private var resultsQuery = ""

    private var library: KanjiLibrary { model.kanji }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        StudySplit(selection: $selection, placeholder: "Choose a kanji") {
            VStack(alignment: .leading, spacing: 16) {
                searchField
                if !isSearching {
                    gradePicker
                }
                if isSearching {
                    let isCurrent = resultsQuery == trimmedSearch
                    Text(isCurrent ? "\(results.count) found" : "Searching…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if isCurrent, results.isEmpty {
                        notFound(resultsQuery)
                    }
                    grid(results)
                } else {
                    let groups = library.groups(grade: grade)
                    Text("\(grade == 7 ? "Secondary school" : "Grade \(grade)"): \(groups.reduce(0) { $0 + $1.kanji.count }) kanji")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(group.emoji) \(group.title)")
                                    .font(.headline)
                                Text("\(group.kanji.count)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if picking != nil {
                                    Spacer()
                                    let ids = group.kanji.map(\.character)
                                    let allChecked = ids.allSatisfy { picking?.contains($0) == true }
                                    Button(allChecked ? "Deselect all" : "Select all") { picking?.toggleAll(ids) }
                                        .font(.subheadline)
                                }
                            }
                            grid(group.kanji)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        } detail: { info in
            KanjiDetailView(model: model, info: info)
        }
        .task { await library.prepareSearch() }
        .task(id: trimmedSearch) {
            let query = trimmedSearch
            guard !query.isEmpty else {
                results = []
                resultsQuery = ""
                return
            }
            // Wait until she pauses typing.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let found = await library.search(query)
            guard !Task.isCancelled else { return }
            results = found
            resultsQuery = query
        }
    }

    /// Nothing among the school kanji: explain why, and offer to look the word up in Write.
    private func notFound(_ query: String) -> some View {
        ContentUnavailableView {
            Label("Not a school kanji", systemImage: "magnifyingglass")
        } description: {
            Text("“\(query)” isn't among the 2,136 kanji children learn at school. Words like this are often written in kana, or with a rarer kanji.")
        } actions: {
            Button("Look up “\(query)” in Write", systemImage: "pencil.and.scribble") {
                searchFocused = false
                model.lookUp(query)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func grid(_ kanji: [KanjiInfo]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
            ForEach(kanji) { info in
                tile(info)
            }
        }
    }

    private var searchField: some View {
        SearchField(
            prompt: "Search: mountain, やま, yama or 山",
            text: $searchText,
            focus: $searchFocused,
            onSubmit: { searchFocused = false }
        )
        .frame(maxWidth: 420)
    }

    private var gradePicker: some View {
        FlowLayout(spacing: 8, lineSpacing: 8, centered: false) {
            ForEach(1...7, id: \.self) { level in
                let isSelected = level == grade
                Button {
                    grade = level
                } label: {
                    Text(level == 7 ? "Secondary" : "Grade \(level)")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isSelected ? Color.orange.opacity(0.25) : Color.secondary.opacity(0.1)))
                        .overlay(Capsule().strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tile(_ info: KanjiInfo) -> some View {
        let isPicking = picking != nil
        let isSelected = !isPicking && selection == info
        let isChecked = picking?.contains(info.character) == true
        let emoji = KanjiEmoji.map[info.character] ?? model.kanjiExplainer.explanations[info.character]?.emoji
        return Button {
            if isPicking {
                picking?.toggle(info.character)
            } else {
                selection = info
                Pronouncer.shared.speak(info.mainReading)
            }
        } label: {
            VStack(spacing: 2) {
                Text(info.character)
                    .font(.handwriting(size: 34))
                Text(info.shortMeaning)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .overlay(alignment: .topTrailing) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 14))
                        .padding(4)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.25) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .bottomTrailing) {
                if isPicking { SelectionCheckmark(isChecked: isChecked) }
            }
            .opacity(isPicking && !isChecked ? 0.75 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(info.character), \(info.shortMeaning)")
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

/// One kanji: meaning, readings, the AI explanation, and how to write it.
struct KanjiDetailView: View {
    let model: AppModel
    let info: KanjiInfo

    private var explainer: KanjiExplainer { model.kanjiExplainer }
    private var explanation: KanjiExplanation? { explainer.explanations[info.character] }
    private var emoji: String? { KanjiEmoji.map[info.character] ?? explanation?.emoji }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            readings
            aiCard
            strokes
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: info.character) {
            await explainer.explain(info, model: model.settings.model)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            Text(info.character)
                .font(.handwriting(size: 88))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if let emoji { Text(emoji).font(.largeTitle) }
                    Text(explanation?.meaning ?? info.shortMeaning)
                        .font(.title2.weight(.semibold))
                }
                if info.meanings.count > 1 {
                    Text(info.meanings.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    badge(info.grade == 7 ? "Secondary school" : "Grade \(info.grade)")
                    badge("\(info.strokes) strokes")
                }
            }
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.orange.opacity(0.15)))
    }

    private var readings: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !info.kun.isEmpty {
                readingRow("Japanese reading", info.kun)
            }
            if !info.on.isEmpty {
                readingRow("Chinese reading", info.on)
            }
        }
    }

    private func readingRow(_ title: String, _ readings: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6, lineSpacing: 6, centered: false) {
                ForEach(readings, id: \.self) { reading in
                    let clean = KanjiInfo.clean(reading)
                    Button {
                        Pronouncer.shared.speak(clean)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2.fill").font(.caption)
                            Text(clean).font(.handwriting(size: 18))
                            Text(JapaneseText.romaji(clean)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Explanation", systemImage: "sparkles")
                .font(.headline)
            if let explanation {
                Text(explanation.explanation)
                if !explanation.memoryTip.isEmpty {
                    Label(explanation.memoryTip, systemImage: "lightbulb")
                        .foregroundStyle(.orange)
                }
                if !explanation.examples.isEmpty {
                    Text("Words with \(info.character)")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 4)
                    ForEach(explanation.examples, id: \.self) { example in
                        Button {
                            Pronouncer.shared.speak(example.reading)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(example.word).font(.handwriting(size: 22))
                                Text(example.reading).foregroundStyle(.orange)
                                Text("– \(example.meaning)").foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                                Image(systemName: "speaker.wave.2").foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if explainer.loading.contains(info.character) {
                ProgressView("Asking for a nice explanation…")
            } else if let error = explainer.errors[info.character] {
                Text(error).foregroundStyle(.secondary)
                Button("Try again") {
                    Task { await explainer.explain(info, model: model.settings.model) }
                }
                .buttonStyle(.bordered)
            } else if !explainer.hasAPIKey {
                Text("Add an OpenRouter key in Settings to get a friendly explanation with example words.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.08)))
    }

    @ViewBuilder
    private var strokes: some View {
        switch model.library.loadState {
        case .ready:
            WordStrokesView(
                word: WordCandidate(
                    japanese: info.character,
                    reading: info.mainReading,
                    romaji: JapaneseText.romaji(info.mainReading),
                    meaning: info.shortMeaning,
                    emoji: emoji ?? "",
                    isLoanword: false,
                    parts: [.init(text: info.character, reading: info.mainReading)]
                ),
                library: model.library,
                speaksOnTap: false,
                showRomaji: true,
                showsTiles: false
            )
            .frame(maxWidth: .infinity)
        case .loading:
            ProgressView()
        case .failed(let message):
            Text(message).foregroundStyle(.secondary)
        }
    }
}
