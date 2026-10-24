import Foundation

/// Minimal client for the Claude API (Anthropic's Messages endpoint).
nonisolated struct ClaudeClient: AIClient {
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let apiVersion = "2023-06-01"

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
        // Claude thinks before answering, so it gets a little longer than OpenRouter.
        var request = URLRequest(url: Self.endpoint, timeoutInterval: imageJPEG == nil ? 60 : 90)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var userContent: [[String: Any]] = []
        if let imageJPEG {
            userContent.append([
                "type": "image",
                "source": ["type": "base64", "media_type": "image/jpeg", "data": imageJPEG.base64EncodedString()],
            ])
        }
        userContent.append(["type": "text", "text": user])
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "system": system,
            "messages": [
                ["role": "user", "content": userContent],
            ],
            "output_config": [
                // Keep thinking short: a child is waiting for the answer.
                "effort": "low",
                // Structured output: the answer is JSON that matches the schema.
                "format": ["type": "json_schema", "schema": schema],
            ],
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

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let message = try? decoder.decode(MessageResponse.self, from: data) else {
            throw TranslationError.badResponse
        }
        switch message.stopReason {
        case "refusal":
            // A safety classifier declined (HTTP 200): the content doesn't match the schema.
            throw TranslationError.refused(message.stopDetails?.explanation ?? "")
        case "max_tokens":
            throw TranslationError.badResponse
        default:
            break
        }
        let text = message.content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
        guard let result: Output = AIClientSupport.decodeJSON(text) else {
            throw TranslationError.badResponse
        }
        return result
    }

    /// Maps the Claude API's HTTP status codes (https://platform.claude.com/docs/en/api/errors).
    private static func error(status: Int, data: Data) -> TranslationError {
        let message = errorMessage(in: data)
        let lower = message.lowercased()
        switch status {
        case 401:
            return .invalidAPIKey
        case 402:
            return .outOfCredits
        case 400 where lower.contains("credit"):
            return .outOfCredits
        case 400 where lower.contains("model"):
            return .modelUnavailable
        case 404:
            // Unknown model, or one this account can't use.
            return .modelUnavailable
        case 408:
            return .timedOut
        case 429 where lower.contains("spend"):
            return .keyLimitReached
        case 429:
            return .rateLimited
        case 500...599:
            // 529 is "overloaded".
            return .serviceDown
        default:
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

private nonisolated struct MessageResponse: Decodable {
    nonisolated struct Block: Decodable {
        let type: String
        let text: String?
    }
    nonisolated struct StopDetails: Decodable {
        let explanation: String?
    }
    let content: [Block]
    let stopReason: String?
    let stopDetails: StopDetails?
}

private nonisolated struct ErrorResponse: Decodable {
    nonisolated struct Detail: Decodable {
        let type: String?
        let message: String
    }
    let error: Detail
}
