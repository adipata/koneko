import Foundation

/// Deals one Review session: the cards that are due (the ones she's most likely to have
/// forgotten first), with a few new cards mixed in. A card she didn't know yet comes back a few
/// cards later. The session is short, so a long break never turns into a wall of cards.
struct ReviewDealer {
    /// Cards in one session (not counting missed cards coming back).
    static let sessionSize = 20
    /// New cards always get at least this many places, even when many cards are due.
    static let minNewPlaces = 5
    /// A missed card comes back after this many other cards.
    static let relearnGap = 3
    /// A card missed this many times in one session waits for next time.
    static let maxMisses = 3

    private var queue: [FlashCard]
    private var misses: [String: Int] = [:]

    /// - Parameters:
    ///   - newLimit: how many cards she hasn't met yet may be added.
    init(cards: [FlashCard], direction: FlashDirection, states: [String: ReviewState], newLimit: Int, now: Date = .now) {
        var seen = Set<String>()
        let unique = cards.filter { seen.insert($0.key).inserted }

        let due = unique
            .compactMap { card -> (card: FlashCard, recall: Double)? in
                guard let state = states[card.reviewKey(direction)], state.due <= now else { return nil }
                return (card, FSRS.retrievability(state, at: now))
            }
            .sorted { $0.recall < $1.recall }
            .map(\.card)
        let fresh = unique.filter { states[$0.reviewKey(direction)] == nil }.prefix(max(newLimit, 0))

        let dueTaken = min(due.count, Self.sessionSize - min(fresh.count, Self.minNewPlaces))
        let newTaken = min(fresh.count, Self.sessionSize - dueTaken)
        queue = Self.interleave(Array(due.prefix(dueTaken)), Array(fresh.prefix(newTaken)))
    }

    /// Cards left in this session, including the one about to be dealt.
    var remaining: Int { queue.count }

    mutating func next() -> FlashCard? {
        queue.isEmpty ? nil : queue.removeFirst()
    }

    /// After she answers: a card she didn't know yet comes back a few cards later.
    mutating func answered(_ card: FlashCard, _ rating: ReviewRating) {
        guard rating == .notYet else { return }
        let count = (misses[card.key] ?? 0) + 1
        misses[card.key] = count
        guard count < Self.maxMisses else { return }
        queue.insert(card, at: min(Self.relearnGap, queue.count))
    }

    /// Spreads the new cards evenly between the due ones.
    private static func interleave(_ due: [FlashCard], _ fresh: [FlashCard]) -> [FlashCard] {
        guard !fresh.isEmpty else { return due }
        var result = due
        let step = Double(due.count) / Double(fresh.count + 1)
        for (index, card) in fresh.enumerated() {
            let position = Int((Double(index + 1) * step).rounded()) + index
            result.insert(card, at: min(position, result.count))
        }
        return result
    }
}
