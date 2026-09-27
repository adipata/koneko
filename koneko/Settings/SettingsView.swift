import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let translator: Translator
    let history: HistoryStore

    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = Keychain.apiKey ?? ""
    @State private var savedKey = Keychain.apiKey ?? ""
    @State private var keyError: String?
    @State private var customModel = ""
    @State private var showCredits = false
    @State private var confirmClear = false
    @State private var confirmDeleteWords = false
    @State private var exportDocument: DictionaryDocument?
    @State private var showImporter = false
    @State private var pendingImport: Data?
    @State private var dictionaryMessage: String?
    private let pronouncer = Pronouncer.shared

    private var voiceDownloadHint: String {
        #if os(macOS)
        "For a nicer voice, download a Japanese voice such as Kyoko (Enhanced or Premium): System Settings → Accessibility → Spoken Content → System Voice → Manage Voices."
        #else
        "For a nicer voice, download a Japanese voice such as Kyoko (Enhanced or Premium): Settings → Accessibility → Spoken Content → Voices → Japanese."
        #endif
    }

    private var isPresetModel: Bool {
        AppSettings.modelOptions.contains { $0.id == settings.model }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API key", text: $apiKey, prompt: Text("sk-or-…"))
                        .autocorrectionDisabled()
                        .onSubmit { saveKey() }
                    HStack {
                        keyStatus
                        Spacer()
                        Button("Save key") { saveKey() }
                            .disabled(trimmedKey == savedKey)
                    }
                    Link("Get a key at openrouter.ai/keys", destination: URL(string: "https://openrouter.ai/keys")!)
                } header: {
                    Text("OpenRouter API key")
                } footer: {
                    Text("Stored securely in the Keychain on this device. Tip: give this key a small credit limit on OpenRouter.")
                }

                Section {
                    Picker("Model", selection: $settings.model) {
                        ForEach(AppSettings.modelOptions) { option in
                            VStack(alignment: .leading) {
                                Text(option.name)
                                Text(option.note).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(option.id)
                        }
                        if !isPresetModel {
                            Text(settings.model).tag(settings.model)
                        }
                    }
                    .pickerStyle(.inline)

                    HStack {
                        TextField("Other model", text: $customModel, prompt: Text("e.g. anthropic/claude-haiku-4.5"))
                            .autocorrectionDisabled()
                            .onSubmit(useCustomModel)
                        Button("Use", action: useCustomModel)
                            .disabled(customModel.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("AI model")
                } footer: {
                    Text("Any model ID from openrouter.ai/models works.")
                }

                Section {
                    Picker("Write words", selection: $settings.writingStyle) {
                        ForEach(WritingStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    if settings.writingStyle == .schoolLevel {
                        Picker("Kanji she knows", selection: $settings.kanjiLevel) {
                            ForEach(0...7, id: \.self) { level in
                                Text(WritingStyle.levelName(level)).tag(level)
                            }
                        }
                    }
                    Toggle("Show readings above kanji (furigana)", isOn: $settings.showFurigana)
                } header: {
                    Text("How words are written")
                } footer: {
                    Text("With “Only kanji she has learned”, kanji above her level are written in hiragana, like in Japanese children's books.")
                }

                Section("Learning") {
                    Picker("She types or says words in", selection: $settings.inputLanguage) {
                        ForEach(InputLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    Toggle("Show romaji (Latin letters)", isOn: $settings.showRomaji)
                }

                Section {
                    Toggle("Say words automatically", isOn: $settings.speakAutomatically)
                    LabeledContent("Japanese voice", value: pronouncer.voiceDescription)
                    Button("Test voice") {
                        pronouncer.refreshVoice()
                        pronouncer.speak("こんにちは。ねこ。")
                    }
                } header: {
                    Text("Pronunciation")
                } footer: {
                    Text(pronouncer.hasGoodVoice
                         ? "Using a high-quality voice."
                         : voiceDownloadHint)
                }

                Section {
                    Button("Forget saved translations (\(translator.cachedWordCount))", role: .destructive) {
                        confirmClear = true
                    }
                    .disabled(translator.cachedWordCount == 0)
                } footer: {
                    Text("Translations already looked up are saved on this device and work offline. This doesn't change “My words”.")
                }

                Section {
                    LabeledContent("Words", value: "\(history.entries.count)")
                    LabeledContent("Folders", value: "\(history.folders.count)")
                    Button("Export my words…", systemImage: "square.and.arrow.up") { exportWords() }
                        .disabled(history.entries.isEmpty)
                    Button("Import words…", systemImage: "square.and.arrow.down") { showImporter = true }
                    Button("Delete all my words…", systemImage: "trash", role: .destructive) {
                        confirmDeleteWords = true
                    }
                    .disabled(history.entries.isEmpty && history.folders.isEmpty)
                    if let dictionaryMessage {
                        Text(dictionaryMessage)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("My words")
                } footer: {
                    Text("Export saves her words, folders, pins and stars as a JSON file, e.g. to keep a backup or move them to another iPad or Mac.")
                }

                Section {
                    Button("Credits") { showCredits = true }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if saveKey() { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $showCredits) { CreditsView() }
            #if os(macOS)
            .frame(minWidth: 520, idealWidth: 560, minHeight: 620, idealHeight: 700)
            #endif
            .confirmationDialog("Forget all saved translations?", isPresented: $confirmClear) {
                Button("Forget saved translations", role: .destructive) { translator.clearCache() }
            }
            .confirmationDialog(
                "Delete all \(history.entries.count) words and \(history.folders.count) folders?",
                isPresented: $confirmDeleteWords,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) {
                    history.removeAll()
                    dictionaryMessage = "All words were deleted."
                }
            } message: {
                Text("This can't be undone. Tip: export your words first to keep a backup.")
            }
            .fileExporter(
                isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
                document: exportDocument,
                contentType: .json,
                defaultFilename: "Koneko words \(Date.now.formatted(.iso8601.year().month().day()))"
            ) { result in
                switch result {
                case .success: dictionaryMessage = "Words exported."
                case .failure(let error): dictionaryMessage = "Export failed: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                readImport(result)
            }
            .confirmationDialog(
                "Import words",
                isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                titleVisibility: .visible
            ) {
                Button("Add to my words") { finishImport(replacing: false) }
                Button("Replace my words", role: .destructive) { finishImport(replacing: true) }
            } message: {
                Text("Add the imported words to hers, or replace all her words with the file's?")
            }
        }
    }

    private var trimmedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var keyStatus: some View {
        if let keyError {
            Label(keyError, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        } else if savedKey.isEmpty {
            Label("No key saved yet", systemImage: "key")
                .foregroundStyle(.secondary)
        } else if trimmedKey == savedKey {
            Label("Key saved", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Label("Not saved yet", systemImage: "pencil")
                .foregroundStyle(.orange)
        }
    }

    private func exportWords() {
        do {
            exportDocument = DictionaryDocument(data: try history.exportData())
        } catch {
            dictionaryMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func readImport(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                _ = try DictionaryFile.decode(data) // check it's a Koneko file before asking
                pendingImport = data
            } catch {
                dictionaryMessage = "This file isn't a Koneko word list."
            }
        case .failure(let error):
            dictionaryMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    private func finishImport(replacing: Bool) {
        guard let data = pendingImport else { return }
        pendingImport = nil
        do {
            let count = try history.importData(data, replacing: replacing)
            dictionaryMessage = replacing ? "Imported \(count) words." : "Added \(count) new words."
        } catch {
            dictionaryMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    /// Saves the key if it changed. Returns false if saving failed.
    @discardableResult
    private func saveKey() -> Bool {
        let key = trimmedKey
        guard key != savedKey else { return true }
        keyError = Keychain.setAPIKey(key)
        guard keyError == nil else { return false }
        // Read it back to be sure it's really stored.
        savedKey = Keychain.apiKey ?? ""
        if savedKey != key {
            keyError = "The key was saved but couldn't be read back from the Keychain."
            return false
        }
        return true
    }

    private func useCustomModel() {
        let model = customModel.trimmingCharacters(in: .whitespaces)
        guard !model.isEmpty else { return }
        settings.model = model
        customModel = ""
    }
}
