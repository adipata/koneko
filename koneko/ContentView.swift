import SwiftUI

struct ContentView: View {
    @State private var library = StrokeLibrary()
    @State private var translator = Translator()
    @State private var settings = AppSettings()
    @State private var speech = SpeechInput()
    @State private var history = HistoryStore()
    @State private var showHistory = false

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
                        WordCardView(word: shown, showRomaji: settings.showRomaji, showFurigana: settings.showFurigana)
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
                SettingsView(settings: settings, translator: translator)
            }
        }
        .task { await library.load() }
        .onChange(of: selectedWord) {
            guard let word = selectedWord else { return }
            history.record(word)
            if settings.speakAutomatically {
                Pronouncer.shared.speak(word.spokenText)
            }
        }
        .onChange(of: translator.status) {
            if case .results(let candidates) = translator.status {
                selectedWord = candidates.first
            }
        }
    }

    // MARK: Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        if JapaneseText.isJapanese(text) {
            // Already written in Japanese: show it directly, no AI needed.
            translator.reset()
            selectedWord = .direct(text)
        } else {
            translator.translate(text, language: settings.inputLanguage, settings: settings)
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
