import Foundation

/// Everything that can go wrong when asking the AI (OpenRouter).
/// `AIProblem` turns each case into a clear message for the screen.
nonisolated enum TranslationError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidAPIKey
    /// The OpenRouter account has no credit left (HTTP 402).
    case outOfCredits
    /// The API key's own spending limit is reached.
    case keyLimitReached
    case rateLimited
    /// The chosen model doesn't exist (any more) or has no provider.
    case modelUnavailable
    /// OpenRouter or the model's provider is down or overloaded (5xx).
    case serviceDown
    /// The request was refused, e.g. by moderation.
    case refused(String)
    case server(status: Int, message: String)
    case badResponse
    /// No internet connection at all.
    case offline
    /// The request took too long.
    case timedOut
    /// There is a connection, but OpenRouter can't be reached.
    case cannotReach
    /// Another network problem.
    case network(String)

    var errorDescription: String? {
        let problem = AIProblem(self)
        return "\(problem.title). \(problem.message)"
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
        } catch let error as URLError {
            throw Self.error(for: error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw Self.error(status: status, data: data)
        }

        let completion = try? JSONDecoder().decode(ChatCompletion.self, from: data)
        guard let content = completion?.choices.first?.message.content,
              let result: Output = Self.decodeJSON(content)
        else {
            // OpenRouter sometimes answers 200 with an error inside (e.g. the provider failed).
            if let detail = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw Self.error(status: detail.error.code ?? 0, data: data)
            }
            throw TranslationError.badResponse
        }
        return result
    }

    private static func error(for error: URLError) -> Error {
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

    /// Maps OpenRouter's HTTP status codes (https://openrouter.ai/docs/api-reference/errors).
    private static func error(status: Int, data: Data) -> TranslationError {
        let message = errorMessage(in: data)
        let lower = message.lowercased()
        switch status {
        case 401:
            return .invalidAPIKey
        case 402:
            return .outOfCredits
        case 403 where lower.contains("limit"):
            return .keyLimitReached
        case 403:
            return .refused(message)
        case 404:
            return .modelUnavailable
        case 400 where lower.contains("model"):
            return .modelUnavailable
        case 408:
            return .timedOut
        case 429:
            return .rateLimited
        case 500...599:
            return .serviceDown
        default:
            if lower.contains("credit") { return .outOfCredits }
            return .server(status: status, message: message)
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
    nonisolated struct Detail: Decodable {
        let message: String
        let code: Int?
    }
    let error: Detail
}
