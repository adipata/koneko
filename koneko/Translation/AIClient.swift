import Foundation

/// Everything that can go wrong when asking the AI (OpenRouter or the Claude API).
/// `AIProblem` turns each case into a clear message for the screen.
nonisolated enum TranslationError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidAPIKey
    /// The account has no credit left (e.g. HTTP 402).
    case outOfCredits
    /// The API key's (or its workspace's) own spending limit is reached.
    case keyLimitReached
    case rateLimited
    /// The chosen model doesn't exist (any more) or has no provider.
    case modelUnavailable
    /// The service or the model's provider is down or overloaded (5xx).
    case serviceDown
    /// The request was refused, e.g. by moderation or a safety classifier.
    case refused(String)
    case server(status: Int, message: String)
    case badResponse
    /// No internet connection at all.
    case offline
    /// The request took too long.
    case timedOut
    /// There is a connection, but the service can't be reached.
    case cannotReach
    /// Another network problem.
    case network(String)

    var errorDescription: String? {
        let problem = AIProblem(self)
        return "\(problem.title). \(problem.message)"
    }
}

/// A service that runs the AI models. Each one has its own API key (in the Keychain) and
/// its own list of models; the grown-up picks one in Settings.
nonisolated enum AIProvider: String, CaseIterable, Identifiable, Sendable {
    /// OpenRouter: one key for models from many companies (OpenAI-compatible API).
    case openRouter
    /// Anthropic's Claude API (Messages endpoint).
    case claude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openRouter: "OpenRouter"
        case .claude: "Claude"
        }
    }

    /// Where keys and credit are managed, as shown in messages.
    var website: String {
        switch self {
        case .openRouter: "openrouter.ai"
        case .claude: "platform.claude.com"
        }
    }

    var keysURL: URL {
        switch self {
        case .openRouter: URL(string: "https://openrouter.ai/settings/keys")!
        case .claude: URL(string: "https://platform.claude.com/settings/keys")!
        }
    }

    var creditsURL: URL {
        switch self {
        case .openRouter: URL(string: "https://openrouter.ai/settings/credits")!
        case .claude: URL(string: "https://platform.claude.com/settings/billing")!
        }
    }

    /// How a key from this service starts (shown as the field's placeholder).
    var keyPlaceholder: String {
        switch self {
        case .openRouter: "sk-or-…"
        case .claude: "sk-ant-…"
        }
    }

    /// Advice for the grown-up who saves the key.
    var keyTip: String {
        switch self {
        case .openRouter: "Tip: give this key a small credit limit on OpenRouter."
        case .claude: "Tip: on platform.claude.com, give the key's workspace a small monthly spend limit."
        }
    }

    /// The models offered in Settings; the first one is the default.
    var modelOptions: [AIModelOption] {
        switch self {
        case .openRouter:
            [
                AIModelOption(id: "google/gemini-3.7-flash", name: "Gemini 3.7 Flash", note: "Recommended: fast and good at Japanese"),
                AIModelOption(id: "google/gemini-3.6-flash", name: "Gemini 3.6 Flash", note: "Previous Flash version"),
                AIModelOption(id: "openai/gpt-5-mini", name: "GPT-5 mini", note: "Cheaper, a bit slower"),
                AIModelOption(id: "deepseek/deepseek-v3.2", name: "DeepSeek V3.2", note: "Very cheap", readsImages: false),
            ]
        case .claude:
            [
                AIModelOption(id: "claude-opus-5-5", name: "Claude Opus 5.5", note: "Recommended: the most capable"),
                AIModelOption(id: "claude-sonnet-5-5", name: "Claude Sonnet 5.5", note: "Faster and cheaper"),
                AIModelOption(id: "claude-haiku-5-5", name: "Claude Haiku 5.5", note: "Fastest and cheapest"),
            ]
        }
    }

    var defaultModel: String { modelOptions[0].id }

    /// An example for the "Other model" field.
    var customModelExample: String {
        switch self {
        case .openRouter: "anthropic/claude-haiku-4.5"
        case .claude: "claude-opus-4-8"
        }
    }

    var customModelHint: String {
        switch self {
        case .openRouter: "Any model ID from openrouter.ai/models works."
        case .claude: "Any Claude model ID from platform.claude.com works (Claude 4.6 or newer)."
        }
    }
}

/// A model offered in Settings.
nonisolated struct AIModelOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let note: String
    /// It can read photos (used for handwriting).
    var readsImages = true
}

/// A model on a given service.
nonisolated struct AIModel: Hashable, Sendable {
    let provider: AIProvider
    let id: String

    /// The client that talks to this model, with the service's key from the Keychain.
    /// Throws `TranslationError.missingAPIKey` when no key is saved for the service.
    @MainActor
    func client() throws -> any AIClient {
        guard let apiKey = Keychain.apiKey(for: provider), !apiKey.isEmpty else {
            throw TranslationError.missingAPIKey
        }
        switch provider {
        case .openRouter:
            return OpenRouterClient(apiKey: apiKey, model: id)
        case .claude:
            return ClaudeClient(apiKey: apiKey, model: id)
        }
    }
}

/// A chat model that must answer with JSON matching a schema. One implementation per service
/// (`OpenRouterClient`, `ClaudeClient`); the prompts and schemas are the same for all.
nonisolated protocol AIClient: Sendable {
    /// Sends a chat request that must answer with JSON matching `schema`, and decodes it.
    /// `imageJPEG`, when given, is sent with the user message (the model must accept images).
    func requestJSON<Output: Decodable & Sendable>(
        system: String,
        user: String,
        imageJPEG: Data?,
        schemaName: String,
        schema: [String: Any]
    ) async throws -> Output
}

nonisolated extension AIClient {
    func requestJSON<Output: Decodable & Sendable>(
        system: String,
        user: String,
        schemaName: String,
        schema: [String: Any]
    ) async throws -> Output {
        try await requestJSON(system: system, user: user, imageJPEG: nil, schemaName: schemaName, schema: schema)
    }

    func translate(_ text: String, language: InputLanguage) async throws -> [WordCandidate] {
        let result: TranslationResult = try await requestJSON(
            system: TranslationPrompt.system,
            user: TranslationPrompt.userMessage(for: text, language: language),
            schemaName: "japanese_words",
            schema: TranslationPrompt.schema
        )
        var seen = Set<String>()
        return result.candidates
            .compactMap { $0.validated() }
            .filter { seen.insert($0.japanese).inserted }
            .prefix(4)
            .map { $0 }
    }
}

nonisolated struct TranslationResult: Decodable, Sendable {
    let candidates: [WordCandidate]
}

/// Helpers shared by the clients.
nonisolated enum AIClientSupport {
    /// Maps a transport error to a `TranslationError` (or a `CancellationError`).
    static func error(for error: URLError) -> Error {
        switch error.code {
        case .cancelled:
            return CancellationError()
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff, .callIsActive:
            return TranslationError.offline
        case .timedOut:
            return TranslationError.timedOut
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .secureConnectionFailed,
             .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateNotYetValid:
            return TranslationError.cannotReach
        default:
            return TranslationError.network(error.localizedDescription)
        }
    }

    /// Parses the model's JSON, tolerating a surrounding ```json fence.
    static func decodeJSON<Output: Decodable>(_ content: String) -> Output? {
        var json = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = json.firstIndex(of: "{"), let end = json.lastIndex(of: "}") {
            json = String(json[start...end])
        }
        return try? JSONDecoder().decode(Output.self, from: Data(json.utf8))
    }
}
