import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let translator: Translator

    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = Keychain.apiKey ?? ""
    @State private var savedKey = Keychain.apiKey ?? ""
    @State private var keyError: String?
    @State private var customModel = ""
    @State private var showCredits = false
    @State private var confirmClear = false

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

                Section("Learning") {
                    Picker("She types or says words in", selection: $settings.inputLanguage) {
                        ForEach(InputLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    Toggle("Show romaji (Latin letters)", isOn: $settings.showRomaji)
                }

                Section {
                    Button("Forget saved words (\(translator.cachedWordCount))", role: .destructive) {
                        confirmClear = true
                    }
                    .disabled(translator.cachedWordCount == 0)
                } footer: {
                    Text("Words already looked up are saved on this device and work offline.")
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
            .confirmationDialog("Forget all saved words?", isPresented: $confirmClear) {
                Button("Forget saved words", role: .destructive) { translator.clearCache() }
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
