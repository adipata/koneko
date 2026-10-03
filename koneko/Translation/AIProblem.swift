import SwiftUI

/// A clear explanation of why the AI helper didn't answer, and what can be done about it.
/// Written so Nathalie understands it, with the details a grown-up needs to fix it.
nonisolated struct AIProblem: Equatable, Sendable {
    let title: String
    let message: String
    let systemImage: String
    /// Trying again may help (network hiccups, busy servers).
    var canRetry = true
    /// The fix is in Koneko's Settings (API key, model).
    var needsSettings = false
    /// The fix is on the OpenRouter website (credit, key limit).
    var link: URL?

    private static let creditsURL = URL(string: "https://openrouter.ai/settings/credits")
    private static let keysURL = URL(string: "https://openrouter.ai/settings/keys")
    private static let worksOffline = "Words you looked up before still work."

    init(title: String, message: String, systemImage: String, canRetry: Bool = true, needsSettings: Bool = false, link: URL? = nil) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.canRetry = canRetry
        self.needsSettings = needsSettings
        self.link = link
    }

    init(_ error: Error) {
        guard let error = error as? TranslationError else {
            self.init(title: "Something went wrong", message: error.localizedDescription, systemImage: "exclamationmark.triangle")
            return
        }
        switch error {
        case .missingAPIKey:
            self.init(
                title: "The AI helper isn't set up yet",
                message: "A grown-up needs to add an OpenRouter API key in Settings.",
                systemImage: "key", canRetry: false, needsSettings: true
            )
        case .invalidAPIKey:
            self.init(
                title: "The AI key doesn't work",
                message: "OpenRouter didn't accept the API key. A grown-up can check or replace it in Settings.",
                systemImage: "key.slash", canRetry: false, needsSettings: true, link: Self.keysURL
            )
        case .outOfCredits:
            self.init(
                title: "The AI helper is out of credit",
                message: "The OpenRouter account has no credit left. A grown-up can add credit on openrouter.ai. \(Self.worksOffline)",
                systemImage: "creditcard.trianglebadge.exclamationmark", canRetry: false, link: Self.creditsURL
            )
        case .keyLimitReached:
            self.init(
                title: "The AI key reached its spending limit",
                message: "A grown-up can raise the key's limit on openrouter.ai, or use another key in Settings. \(Self.worksOffline)",
                systemImage: "gauge.with.dots.needle.100percent", canRetry: false, needsSettings: true, link: Self.keysURL
            )
        case .rateLimited:
            self.init(
                title: "Too many questions at once",
                message: "The AI needs a little break. Wait a moment and try again.",
                systemImage: "hourglass"
            )
        case .modelUnavailable:
            self.init(
                title: "This AI model isn't available",
                message: "The chosen model can't be used right now. A grown-up can pick another model in Settings.",
                systemImage: "cpu", canRetry: false, needsSettings: true
            )
        case .serviceDown:
            self.init(
                title: "The AI service is having trouble",
                message: "It isn't answering right now. Try again later, or pick another model in Settings.",
                systemImage: "cloud.bolt", needsSettings: true
            )
        case .refused:
            self.init(
                title: "The AI didn't want to answer that",
                message: "Try a different word.",
                systemImage: "hand.raised", canRetry: false
            )
        case .server(let status, let message):
            self.init(
                title: "The AI service had a problem",
                message: "OpenRouter error \(status): \(message)",
                systemImage: "exclamationmark.icloud"
            )
        case .badResponse:
            self.init(
                title: "The AI's answer got muddled",
                message: "Try again. If it keeps happening, a grown-up can pick another model in Settings.",
                systemImage: "questionmark.bubble", needsSettings: true
            )
        case .offline:
            self.init(
                title: "No internet connection",
                message: "Connect to Wi-Fi and try again. \(Self.worksOffline)",
                systemImage: "wifi.slash"
            )
        case .timedOut:
            self.init(
                title: "The AI took too long to answer",
                message: "The internet may be slow. Try again in a moment.",
                systemImage: "clock.badge.exclamationmark"
            )
        case .cannotReach:
            self.init(
                title: "Can't reach the AI service",
                message: "OpenRouter can't be reached. Check the internet connection (some Wi-Fi networks block it) or try again later.",
                systemImage: "network.slash"
            )
        case .network(let message):
            self.init(
                title: "Internet problem",
                message: message,
                systemImage: "wifi.exclamationmark"
            )
        }
    }
}

/// Shows an `AIProblem` with the buttons that can fix it.
struct AIProblemView: View {
    let problem: AIProblem
    var retry: (() -> Void)?
    var openSettings: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: problem.systemImage)
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(problem.title)
                .font(.headline)
            Text(problem.message)
                .font(.callout)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                if let retry, problem.canRetry {
                    Button("Try again", systemImage: "arrow.clockwise", action: retry)
                }
                if let openSettings, problem.needsSettings {
                    Button("Settings", systemImage: "gear", action: openSettings)
                }
                if let link = problem.link {
                    Link(destination: link) {
                        Label("Open OpenRouter", systemImage: "safari")
                    }
                }
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: 480)
    }
}
