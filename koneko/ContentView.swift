import SwiftUI

struct ContentView: View {
    @State private var library = StrokeLibrary()
    @State private var translator = Translator()
    @State private var settings = AppSettings()
    @State private var speech = SpeechInput()
    @State private var history = HistoryStore()
    @State private var watchSync = WatchSyncController()
    @State private var showHistory = false
    @State private var lastLookupWasJapanese = false

    @State private var input = ""
    @State private var selectedWord: WordCandidate?
    /// Other things speech recognition thought she might have said.
    @State private var heardAlternatives: [String] = []
    @State private var showSettings = false
    @FocusState private var inputFocused: Bool

    private var sampleWords: [String] {
        switch settings.inputLanguage {
        case .english: ["cat", "dog", "school", "apple", "rain", "thank you", "bat"]
        case .japanese: ["ねこ", "猫", "がっこう", "はし", "ありがとう"]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    inputSection
                    statusSection
                    if let word = selectedWord {
                        let shown = settings.display(word)
                        WordCardView(word: shown, showRomaji: settings.showRomaji, showFurigana: settings.showFurigana, original: word)
                        strokesSection(for: shown, original: word)
                    }
                }
                .padding()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Koneko 🐱")
            .toolbar {
                Button("My words", systemImage: "book") { showHistory = true }
                Button("Settings", systemImage: "gearshape") { showSettings = true }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(history: history, style: settings.display) { word in
                    translator.reset()
                    heardAlternatives = []
                    input = ""
                    selectedWord = word
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: settings, translator: translator, history: history, watchSync: watchSync)
            }
        }
        .task { await library.load() }
        .onChange(of: watchSyncKey, initial: true) {
            watchSync.update(history: history, settings: settings)
        }
        .onChange(of: selectedWord) {
            guard let word = selectedWord else { return }
            history.record(word)
            if settings.speakAutomatically {
                Pronouncer.shared.speak(word.spokenText)
            }
        }
        .onChange(of: translator.status) {
            switch translator.status {
            case .results(let candidates):
                selectedWord = candidates.first ?? directWordIfJapanese()
            case .failed where lastLookupWasJapanese:
                // Offline or AI error: Japanese text can still be shown and practised.
                selectedWord = directWordIfJapanese()
            default:
                break
            }
        }
    }

    // MARK: Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("I speak", selection: languageBinding) {
                Text("🇬🇧 English").tag(InputLanguage.english)
                Text("🇯🇵 日本語").tag(InputLanguage.japanese)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 300)
            .frame(maxWidth: .infinity)
            .disabled(speech.status != .idle)

            HoldToTalkButton(speech: speech, language: settings.inputLanguage) { result in
                input = result.text
                lookUp()
                heardAlternatives = Array(result.alternatives.prefix(3))
            }
            .frame(maxWidth: .infinity)

            if !heardAlternatives.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    Text("Or did you say:")
                        .foregroundStyle(.secondary)
                    ForEach(heardAlternatives, id: \.self) { alternative in
                        Button(alternative) {
                            // Swap: the word shown now becomes one of the alternatives.
                            let others = heardAlternatives.map { $0 == alternative ? input : $0 }
                            input = alternative
                            lookUp()
                            heardAlternatives = others
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            HStack {
                TextField(placeholder, text: $input)
                    .font(.title2)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .focused($inputFocused)
                    .submitLabel(.search)
                    .onSubmit(lookUp)
                Button("Look up", systemImage: "magnifyingglass", action: lookUp)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .buttonStyle(.borderedProminent)
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            FlowLayout(spacing: 8, lineSpacing: 8, centered: false) {
                ForEach(sampleWords, id: \.self) { word in
                    Button(word) {
                        input = word
                        lookUp()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    /// The typed/dictated text as a word, if it's already in Japanese script.
    private func directWordIfJapanese() -> WordCandidate? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return lastLookupWasJapanese && JapaneseText.isJapanese(text) ? .direct(text) : nil
    }

    /// Changes whenever something the watch shows changes.
    private var watchSyncKey: String {
        [
            "\(history.revision)", "\(settings.syncToWatch)", settings.writingStyle.rawValue,
            "\(settings.kanjiLevel)", "\(settings.showRomaji)", "\(settings.showFurigana)",
        ].joined(separator: "|")
    }

    private var languageBinding: Binding<InputLanguage> {
        Binding(
            get: { settings.inputLanguage },
            set: { settings.inputLanguage = $0; heardAlternatives = [] }
        )
    }

    private var placeholder: String {
        switch settings.inputLanguage {
        case .english: "Type a word in English, e.g. cat"
        case .japanese: "Type a word in Japanese or romaji"
        }
    }

    private func lookUp() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputFocused = false
        selectedWord = nil
        heardAlternatives = []
        let isJapaneseScript = JapaneseText.isJapanese(text)
        lastLookupWasJapanese = isJapaneseScript
        if isJapaneseScript, (Keychain.apiKey ?? "").isEmpty {
            // Already written in Japanese and no AI available: show it directly.
            translator.reset()
            selectedWord = .direct(text)
        } else {
            // Japanese text (typed or dictated) still goes to the AI to get the reading,
            // meaning and emoji, and to offer other words that sound the same.
            let language: InputLanguage = isJapaneseScript ? .japanese : settings.inputLanguage
            translator.translate(text, language: language, settings: settings)
            // Saved words answer instantly, and onChange won't fire if the result is unchanged.
            if case .results(let candidates) = translator.status {
                selectedWord = candidates.first
            }
        }
    }

    // MARK: Results

    @ViewBuilder
    private var statusSection: some View {
        switch translator.status {
        case .idle:
            if selectedWord == nil {
                ContentUnavailableView(
                    "What word do you want to write?",
                    systemImage: "pencil.and.scribble",
                    description: Text("Say it or type it, and I'll show you how to write it in Japanese.")
                )
            }
        case .loading:
            ProgressView("Looking it up…")
                .padding(.top, 24)
        case .failed(let message):
            VStack(spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .multilineTextAlignment(.center)
                HStack {
                    Button("Try again", action: lookUp)
                    Button("Settings") { showSettings = true }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        case .results(let candidates):
            if candidates.isEmpty {
                Label("I couldn't find a Japanese word for that. Try another word!", systemImage: "questionmark.circle")
            } else if candidates.count > 1 {
                CandidatePicker(candidates: candidates, selection: $selectedWord)
            }
        }
    }

    @ViewBuilder
    private func strokesSection(for word: WordCandidate, original: WordCandidate) -> some View {
        switch library.loadState {
        case .loading:
            ProgressView("Loading strokes…")
        case .failed(let message):
            ContentUnavailableView(
                "Couldn't load stroke data",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        case .ready:
            WordStrokesView(word: word, library: library, speaksOnTap: settings.speakAutomatically, showRomaji: settings.showRomaji) { character, stars in
                history.recordStars(stars, for: character, in: original)
            }
            .id(word.id)
        }
    }
}

#Preview {
    ContentView()
}
