import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let translator: Translator

    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = Keychain.apiKey ?? ""
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
                    SecureField("sk-or-…", text: $apiKey)
                        .autocorrectionDisabled()
                        .onSubmit(saveKey)
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
                    .labelsHidden()

                    HStack {
                        TextField("Other model ID, e.g. anthropic/claude-haiku-4.5", text: $customModel)
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
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") {
                    saveKey()
                    dismiss()
                }
            }
            .sheet(isPresented: $showCredits) { CreditsView() }
            .confirmationDialog("Forget all saved words?", isPresented: $confirmClear) {
                Button("Forget saved words", role: .destructive) { translator.clearCache() }
            }
        }
    }

    private func saveKey() {
        Keychain.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func useCustomModel() {
        let model = customModel.trimmingCharacters(in: .whitespaces)
        guard !model.isEmpty else { return }
        settings.model = model
        customModel = ""
    }
}
