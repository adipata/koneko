import Foundation

nonisolated enum TranslationError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case outOfCredits
    case rateLimited
    case server(status: Int, message: String)
    case badResponse
    case offline

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "Add your OpenRouter API key in Settings first."
        case .invalidAPIKey: "OpenRouter didn't accept the API key. Check it in Settings."
        case .outOfCredits: "The OpenRouter account is out of credits."
        case .rateLimited: "Too many requests right now. Try again in a moment."
        case .server(let status, let message): "OpenRouter error \(status): \(message)"
        case .badResponse: "The answer from the AI couldn't be understood. Try again or pick another model."
        case .offline: "No internet connection. Words you looked up before still work offline."
        }
    }
}

/// Minimal client for OpenRouter's OpenAI-compatible chat completions endpoint.
nonisolated struct OpenRouterClient: Sendable {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    let apiKey: String
    let model: String
    var session: URLSession = .shared

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

    /// Sends a chat request that must answer with JSON matching `schema`, and decodes it.
    func requestJSON<Output: Decodable & Sendable>(
        system: String,
        user: String,
        schemaName: String,
        schema: [String: Any]
    ) async throws -> Output {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Koneko", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": ["name": schemaName, "strict": true, "schema": schema],
            ],
            // Keep thinking short: a child is waiting for the answer.
            "reasoning": ["effort": "low"],
            "max_tokens": 2000,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .dataNotAllowed].contains(error.code) {
            throw TranslationError.offline
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            switch status {
            case 401: throw TranslationError.invalidAPIKey
            case 402: throw TranslationError.outOfCredits
            case 429: throw TranslationError.rateLimited
            default: throw TranslationError.server(status: status, message: Self.errorMessage(in: data))
            }
        }

        let completion = try? JSONDecoder().decode(ChatCompletion.self, from: data)
        guard let content = completion?.choices.first?.message.content,
              let result: Output = Self.decodeJSON(content)
        else {
            throw TranslationError.badResponse
        }
        return result
    }

    /// Parses the model's JSON, tolerating a surrounding ```json fence.
    static func decodeJSON<Output: Decodable>(_ content: String) -> Output? {
        var json = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = json.firstIndex(of: "{"), let end = json.lastIndex(of: "}") {
            json = String(json[start...end])
        }
        return try? JSONDecoder().decode(Output.self, from: Data(json.utf8))
    }

    private static func errorMessage(in data: Data) -> String {
        if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return error.error.message
        }
        return String(decoding: data.prefix(200), as: UTF8.self)
    }
}

nonisolated struct TranslationResult: Decodable, Sendable {
    let candidates: [WordCandidate]
}

private nonisolated struct ChatCompletion: Decodable {
    nonisolated struct Choice: Decodable { let message: Message }
    nonisolated struct Message: Decodable { let content: String? }
    let choices: [Choice]
}

private nonisolated struct ErrorResponse: Decodable {
    nonisolated struct Detail: Decodable { let message: String }
    let error: Detail
}
