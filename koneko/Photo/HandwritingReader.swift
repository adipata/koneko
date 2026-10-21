#if os(iOS)
import UIKit

/// Reads handwriting from a cropped photo with the AI, since Apple's on-device
/// text recognition only reads printed Japanese reliably. Only the cropped part is sent.
enum HandwritingReader {
    private nonisolated struct ReadText: Decodable, Sendable {
        let text: String
    }

    static func read(_ image: UIImage, model: AIModel) async throws -> String {
        let client = try model.client()
        guard let jpeg = image.jpegData(compressionQuality: 0.8) else { throw TranslationError.badResponse }
        let result: ReadText = try await client.requestJSON(
            system: systemPrompt,
            user: "Read the text in this photo.",
            imageJPEG: jpeg,
            schemaName: "handwritten_text",
            schema: schema
        )
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let systemPrompt = """
    You read text from a photo, for a 9-year-old child learning Japanese.
    The text is usually handwritten, in Japanese (hiragana, katakana, kanji) or in English.
    Return "text": exactly what is written, in the same language and script. Do not translate,
    explain or correct it. Put several lines on one line: Japanese lines joined with nothing,
    English lines joined with a space. If nothing can be read, return an empty string.
    """

    private static var schema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["text"],
            "properties": ["text": ["type": "string"]],
        ]
    }
}

extension UIImage {
    /// The part of the photo inside `unitRect` (0…1 of the upright image), upright and scaled
    /// down so its longest side is at most `maxSide` pixels.
    func cropped(to unitRect: CGRect, maxSide: CGFloat) -> UIImage {
        // `size` and `draw(in:)` already account for the photo's orientation.
        let crop = CGRect(
            x: unitRect.minX * size.width,
            y: unitRect.minY * size.height,
            width: unitRect.width * size.width,
            height: unitRect.height * size.height
        )
        let pixelScale = scale
        let scaleDown = min(1, maxSide / (max(crop.width, crop.height) * pixelScale))
        let factor = pixelScale * scaleDown
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let output = CGSize(width: max(1, (crop.width * factor).rounded()), height: max(1, (crop.height * factor).rounded()))
        return UIGraphicsImageRenderer(size: output, format: format).image { _ in
            draw(in: CGRect(
                x: -crop.minX * factor,
                y: -crop.minY * factor,
                width: size.width * factor,
                height: size.height * factor
            ))
        }
    }
}
#endif
