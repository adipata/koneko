import Foundation

enum KanaScript: String, CaseIterable, Identifiable {
    case hiragana
    case katakana

    var id: String { rawValue }
    var title: String { self == .hiragana ? "Hiragana" : "Katakana" }

    func text(_ hiragana: String) -> String {
        self == .hiragana ? hiragana : JapaneseText.katakana(hiragana)
    }
}

/// One sound in the chart, stored in hiragana (katakana is derived).
struct KanaCell: Identifiable, Hashable {
    let hiragana: String
    let romaji: String
    var id: String { hiragana }
}

/// A row of the chart: a consonant label and its cells (nil = empty spot, e.g. yi, ye).
struct KanaRow: Identifiable {
    let label: String
    let cells: [KanaCell?]
    var id: String { label + cells.map { $0?.hiragana ?? "_" }.joined() }
}

struct KanaSection: Identifiable {
    let title: String
    let columns: [String]
    let rows: [KanaRow]
    var id: String { title }
}

/// The classic gojūon chart, voiced sounds (゛゜) and combined sounds (きゃ…).
enum KanaChart {
    static let sections: [KanaSection] = [
        KanaSection(title: "Basic sounds", columns: ["a", "i", "u", "e", "o"], rows: [
            row("", "あいうえお", "a i u e o"),
            row("k", "かきくけこ", "ka ki ku ke ko"),
            row("s", "さしすせそ", "sa shi su se so"),
            row("t", "たちつてと", "ta chi tsu te to"),
            row("n", "なにぬねの", "na ni nu ne no"),
            row("h", "はひふへほ", "ha hi fu he ho"),
            row("m", "まみむめも", "ma mi mu me mo"),
            row("y", "や_ゆ_よ", "ya _ yu _ yo"),
            row("r", "らりるれろ", "ra ri ru re ro"),
            row("w", "わ___を", "wa _ _ _ wo"),
            row("n", "ん____", "n _ _ _ _"),
        ]),
        KanaSection(title: "With ゛ and ゜", columns: ["a", "i", "u", "e", "o"], rows: [
            row("g", "がぎぐげご", "ga gi gu ge go"),
            row("z", "ざじずぜぞ", "za ji zu ze zo"),
            row("d", "だぢづでど", "da ji zu de do"),
            row("b", "ばびぶべぼ", "ba bi bu be bo"),
            row("p", "ぱぴぷぺぽ", "pa pi pu pe po"),
        ]),
        KanaSection(title: "Combined sounds", columns: ["ya", "yu", "yo"], rows: [
            combined("ky", "き", "kya kyu kyo"),
            combined("sh", "し", "sha shu sho"),
            combined("ch", "ち", "cha chu cho"),
            combined("ny", "に", "nya nyu nyo"),
            combined("hy", "ひ", "hya hyu hyo"),
            combined("my", "み", "mya myu myo"),
            combined("ry", "り", "rya ryu ryo"),
            combined("gy", "ぎ", "gya gyu gyo"),
            combined("j", "じ", "ja ju jo"),
            combined("by", "び", "bya byu byo"),
            combined("py", "ぴ", "pya pyu pyo"),
        ]),
    ]

    static var allCells: [KanaCell] {
        sections.flatMap { $0.rows.flatMap { $0.cells.compactMap { $0 } } }
    }

    /// Finds a sound from typed text: hiragana, katakana or romaji ("ka", "shi", "kya").
    static func find(_ text: String) -> KanaCell? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let cells = allCells
        if JapaneseText.isKana(text) {
            let hiragana = JapaneseText.hiragana(text)
            return cells.first { $0.hiragana == hiragana }
                ?? cells.first { $0.hiragana == String(hiragana.prefix(2)) }
                ?? cells.first { $0.hiragana == String(hiragana.prefix(1)) }
        }
        let romaji = text.lowercased()
        let aliases = ["si": "shi", "ti": "chi", "tu": "tsu", "hu": "fu", "zi": "ji"]
        let key = aliases[romaji] ?? romaji
        return cells.first { $0.romaji == key }
    }

    private static func row(_ label: String, _ kana: String, _ romaji: String) -> KanaRow {
        let names = romaji.split(separator: " ").map(String.init)
        let cells = zip(Array(kana), names).map { character, name -> KanaCell? in
            character == "_" ? nil : KanaCell(hiragana: String(character), romaji: name)
        }
        return KanaRow(label: label, cells: cells)
    }

    private static func combined(_ label: String, _ first: String, _ romaji: String) -> KanaRow {
        let names = romaji.split(separator: " ").map(String.init)
        let cells = zip(["ゃ", "ゅ", "ょ"], names).map { small, name in
            KanaCell(hiragana: first + small, romaji: name) as KanaCell?
        }
        return KanaRow(label: label, cells: cells)
    }
}
