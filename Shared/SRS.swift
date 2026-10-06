import Foundation

/// How she answered a card in Review: two friendly choices, no scores.
nonisolated enum ReviewRating: Int, Codable, Sendable {
    /// 🌱 Not yet (FSRS "Again").
    case notYet = 1
    /// 😺 I knew it (FSRS "Good").
    case knewIt = 3
}

/// Where a card is: being learned, in spaced review, or being learned again after a miss.
nonisolated enum ReviewPhase: String, Codable, Sendable {
    case learning
    case review
    case relearning
}

/// What spaced repetition remembers about one card, in one direction.
nonisolated struct ReviewState: Codable, Equatable, Sendable {
    /// When the card should come back.
    var due: Date
    /// FSRS stability: about how many days until she has a 90 % chance of remembering it.
    var stability: Double
    /// FSRS difficulty, 1 (easy for her) … 10 (hard for her).
    var difficulty: Double
    var phase: ReviewPhase
    var reps: Int
    var lapses: Int
    var lastReview: Date
    /// When she first met the card (to count new cards per day).
    var introduced: Date

    var stage: GardenStage { GardenStage(stability: stability) }
}

/// The visible side of spaced repetition: each card she has met is a plant in her garden.
nonisolated enum GardenStage: Int, CaseIterable, Sendable {
    case sprout
    case growing
    case blooming

    init(stability: Double) {
        switch stability {
        case 21...: self = .blooming
        case 4...: self = .growing
        default: self = .sprout
        }
    }

    var emoji: String {
        switch self {
        case .sprout: "🌱"
        case .growing: "🌿"
        case .blooming: "🌸"
        }
    }

    var title: String {
        switch self {
        case .sprout: "Sprouts"
        case .growing: "Growing"
        case .blooming: "In bloom"
        }
    }
}

/// How many cards of a deck are at each stage, and how many she hasn't met yet.
nonisolated struct Garden: Equatable, Sendable {
    var counts: [GardenStage: Int] = [:]
    var seeds = 0

    func count(_ stage: GardenStage) -> Int { counts[stage] ?? 0 }
    var planted: Int { counts.values.reduce(0, +) }
}

/// FSRS-5 (Free Spaced Repetition Scheduler) with its default parameters, using only the
/// Again and Good answers. It estimates how likely she is to remember each card from the real
/// time since she last saw it, so days or weeks off are handled without special cases.
/// See https://github.com/open-spaced-repetition/fsrs4anki/wiki/The-Algorithm
nonisolated enum FSRS {
    /// Default FSRS-5 parameters (trained on a large set of Anki reviews).
    static let w: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 7.1949, 0.5345, 1.4604, 0.0046, 1.54575, 0.1192,
        1.01925, 1.9395, 0.11, 0.29605, 2.2698, 0.2315, 2.9898, 0.51655, 0.6621,
    ]
    /// The chance of remembering a card when it comes back.
    static let desiredRetention = 0.9
    /// A missed card is due again after this (it also comes back a few cards later in the session).
    static let relearnDelay: TimeInterval = 5 * 60
    static let maxIntervalDays = 3650.0

    private static let decay = -0.5
    private static let factor = 19.0 / 81.0
    private static let day: TimeInterval = 86_400

    /// The chance (0–1) that she remembers the card now.
    static func retrievability(_ state: ReviewState, at now: Date) -> Double {
        let days = max(0, now.timeIntervalSince(state.lastReview) / day)
        return pow(1 + factor * days / state.stability, decay)
    }

    /// The card's state after she answers it (`state` is nil for a card she meets for the first time).
    static func review(_ state: ReviewState?, rating: ReviewRating, at now: Date) -> ReviewState {
        let grade = Double(rating.rawValue)
        guard var card = state else {
            var first = ReviewState(
                due: now, stability: initialStability(grade), difficulty: initialDifficulty(grade),
                phase: .learning, reps: 1, lapses: 0, lastReview: now, introduced: now
            )
            schedule(&first, rating: rating, at: now)
            return first
        }

        let elapsedDays = now.timeIntervalSince(card.lastReview) / day
        if elapsedDays < 1 {
            card.stability = shortTermStability(card.stability, grade)
        } else {
            let recall = retrievability(card, at: now)
            card.stability = rating == .notYet
                ? min(forgetStability(card.difficulty, card.stability, recall), card.stability)
                : recallStability(card.difficulty, card.stability, recall, grade)
        }
        card.stability = max(card.stability, 0.01)
        card.difficulty = nextDifficulty(card.difficulty, grade)
        if rating == .notYet, card.phase == .review { card.lapses += 1 }
        card.reps += 1
        card.lastReview = now
        schedule(&card, rating: rating, at: now)
        return card
    }

    /// Days until the card is due, for a given stability.
    static func intervalDays(_ stability: Double) -> Double {
        let days = stability / factor * (pow(desiredRetention, 1 / decay) - 1)
        return min(max(days.rounded(), 1), maxIntervalDays)
    }

    private static func schedule(_ card: inout ReviewState, rating: ReviewRating, at now: Date) {
        switch rating {
        case .notYet:
            if card.phase == .review { card.phase = .relearning }
            card.due = now.addingTimeInterval(relearnDelay)
        case .knewIt:
            card.phase = .review
            // Due at the start of that day, so it's ready whenever she opens the app.
            let later = now.addingTimeInterval(intervalDays(card.stability) * day)
            card.due = Calendar.current.startOfDay(for: later)
        }
    }

    private static func initialStability(_ grade: Double) -> Double {
        max(w[Int(grade) - 1], 0.1)
    }

    private static func initialDifficulty(_ grade: Double) -> Double {
        clampDifficulty(w[4] - exp(w[5] * (grade - 1)) + 1)
    }

    private static func nextDifficulty(_ difficulty: Double, _ grade: Double) -> Double {
        let change = -w[6] * (grade - 3)
        let damped = difficulty + change * (10 - difficulty) / 9
        // Mean reversion towards the difficulty of an "Easy" first answer.
        return clampDifficulty(w[7] * initialDifficulty(4) + (1 - w[7]) * damped)
    }

    private static func recallStability(_ difficulty: Double, _ stability: Double, _ recall: Double, _ grade: Double) -> Double {
        let hardPenalty = grade == 2 ? w[15] : 1
        let easyBonus = grade == 4 ? w[16] : 1
        let growth = exp(w[8]) * (11 - difficulty) * pow(stability, -w[9]) * (exp(w[10] * (1 - recall)) - 1)
        return stability * (1 + growth * hardPenalty * easyBonus)
    }

    private static func forgetStability(_ difficulty: Double, _ stability: Double, _ recall: Double) -> Double {
        w[11] * pow(difficulty, -w[12]) * (pow(stability + 1, w[13]) - 1) * exp(w[14] * (1 - recall))
    }

    /// Reviews on the same day (e.g. a missed card she gets right a few cards later).
    private static func shortTermStability(_ stability: Double, _ grade: Double) -> Double {
        stability * exp(w[17] * (grade - 3 + w[18]))
    }

    private static func clampDifficulty(_ difficulty: Double) -> Double {
        min(max(difficulty, 1), 10)
    }
}
