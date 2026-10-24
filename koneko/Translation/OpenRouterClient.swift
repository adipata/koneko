import Foundation

/// Minimal client for OpenRouter's OpenAI-compatible chat completions endpoint.
nonisolated struct OpenRouterClient: AIClient {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    let apiKey: String
    let model: String
    var session: URLSession = .shared

    func requestJSON<Output: Decodable & Sendable>(
        system: String,
        user: String,
        imageJPEG: Data?,
        schemaName: String,
        schema: [String: Any]
    ) async throws -> Output {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: imageJPEG == nil ? 30 : 60)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Koneko", forHTTPHeaderField: "X-Title")

        var userContent: Any = user
        if let imageJPEG {
            let parts: [[String: Any]] = [
                ["type": "text", "text": user],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageJPEG.base64EncodedString())"]],
            ]
            userContent = parts
        }
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": userContent],
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
            throw AIClientSupport.error(for: error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw Self.error(status: status, data: data)
        }

        let completion = try? JSONDecoder().decode(ChatCompletion.self, from: data)
        guard let content = completion?.choices.first?.message.content,
              let result: Output = AIClientSupport.decodeJSON(content)
        else {
            // OpenRouter sometimes answers 200 with an error inside (e.g. the provider failed).
            if let detail = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw Self.error(status: detail.error.code ?? 0, data: data)
            }
            throw TranslationError.badResponse
        }
        return result
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

    private static func errorMessage(in data: Data) -> String {
        if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return error.error.message
        }
        return String(decoding: data.prefix(200), as: UTF8.self)
    }
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
