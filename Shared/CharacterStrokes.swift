import SwiftUI

/// Stroke-order data for one character, in KanjiVG's 109×109 coordinate space.
nonisolated struct CharacterStrokes: Decodable, Sendable {
    /// SVG path data for each stroke, in writing order.
    let strokes: [String]
    /// Where KanjiVG places each stroke's number label (text baseline, left edge).
    let numberPositions: [CGPoint]

    static let canvasSize: CGFloat = 109

    private enum CodingKeys: String, CodingKey {
        case strokes = "s"
        case numberPositions = "n"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strokes = try container.decode([String].self, forKey: .strokes)
        let raw = try container.decodeIfPresent([[Double]].self, forKey: .numberPositions) ?? []
        numberPositions = raw.compactMap { $0.count == 2 ? CGPoint(x: $0[0], y: $0[1]) : nil }
    }
}
