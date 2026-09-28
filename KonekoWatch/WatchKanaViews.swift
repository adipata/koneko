import SwiftUI

/// Stroke data for hiragana and katakana (Shared/Resources/kana_strokes.json, from KanjiVG).
enum WatchKanaStrokes {
    static let all: [String: CharacterStrokes] = {
        guard let url = Bundle.main.url(forResource: "kana_strokes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let strokes = try? JSONDecoder().decode([String: CharacterStrokes].self, from: data)
        else { return [:] }
        return strokes
    }()
}

/// Every screen the watch app can push.
enum WatchRoute: Hashable {
    case kanaList(KanaScript)
    case kana(WatchKanaPage)
    case folder(UUID)
    case words(WatchWordPage)
    case flashMenu
    case flash(FlashDeck)
}

/// Navigation value: open the character screen at a sound, in a script.
struct WatchKanaPage: Hashable {
    let script: KanaScript
    let startID: String
}

/// All sounds in chart order (あいうえお かきくけこ …), easy to scroll and pick.
struct WatchKanaListView: View {
    let script: KanaScript

    var body: some View {
        List {
            ForEach(KanaChart.sections) { section in
                Section(section.title) {
                    ForEach(section.rows.flatMap { $0.cells.compactMap { $0 } }) { cell in
                        NavigationLink(value: WatchRoute.kana(WatchKanaPage(script: script, startID: cell.id))) {
                            HStack(spacing: 12) {
                                Text(script.text(cell.hiragana))
                                    .font(.title2)
                                    .frame(minWidth: 44, alignment: .leading)
                                Text(cell.romaji)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(script.title)
    }
}

/// One sound per page, drawn full screen from its strokes.
/// Digital Crown / swipe up-down: next or previous sound. Swipe left-right: hiragana ⇄ katakana.
struct WatchKanaPager: View {
    @State var script: KanaScript
    @State var selection: String

    private let cells = KanaChart.allCells

    var body: some View {
        TabView(selection: $selection) {
            ForEach(cells) { cell in
                WatchKanaCard(cell: cell, script: script)
                    .tag(cell.id)
            }
        }
        .tabViewStyle(.verticalPage)
        .simultaneousGesture(
            DragGesture(minimumDistance: 25).onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 40, abs(dx) > abs(dy) * 1.5 else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    script = script == .hiragana ? .katakana : .hiragana
                }
            }
        )
        .navigationTitle(script == .hiragana ? "ひらがな" : "カタカナ")
    }
}

/// The big character (tap to watch the stroke order), its romaji and a speaker button.
struct WatchKanaCard: View {
    let cell: KanaCell
    let script: KanaScript

    @State private var replay = 0

    private var text: String { script.text(cell.hiragana) }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                    let isSmall = index > 0 // ゃ ゅ ょ in combined sounds
                    WatchKanaGlyph(strokes: WatchKanaStrokes.all[String(character)], fallback: String(character), replay: replay)
                        .frame(maxWidth: isSmall ? 70 : .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { replay += 1 }
            .id(script) // redraw when switching hiragana ⇄ katakana

            HStack(spacing: 10) {
                Text(cell.romaji)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.orange)
                Button {
                    Pronouncer.shared.speak(cell.hiragana)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .frame(width: 40, height: 40)
                .accessibilityLabel("Say it")
            }
        }
        .padding(.horizontal, 4)
    }
}

/// A character drawn from its KanjiVG strokes; draws itself stroke by stroke when `replay` changes.
struct WatchKanaGlyph: View {
    let strokes: CharacterStrokes?
    let fallback: String
    let replay: Int

    @State private var paths: [Path] = []
    @State private var progress: [CGFloat] = []

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let style = StrokeStyle(lineWidth: max(3, side * 0.045), lineCap: .round, lineJoin: .round)
            ZStack {
                if strokes == nil {
                    Text(fallback)
                        .font(.system(size: side * 0.8))
                        .minimumScaleFactor(0.3)
                } else {
                    ForEach(paths.indices, id: \.self) { index in
                        GlyphStroke(path: paths[index])
                            .trim(from: 0, to: progress.indices.contains(index) ? progress[index] : 1)
                            .stroke(Color.primary, style: style)
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: replay) {
            guard let strokes else { return }
            paths = strokes.strokes.map(SVGPath.parse)
            guard replay > 0 else {
                progress = Array(repeating: 1, count: paths.count)
                return
            }
            progress = Array(repeating: 0, count: paths.count)
            for index in paths.indices {
                withAnimation(.easeInOut(duration: 0.45)) { progress[index] = 1 }
                try? await Task.sleep(for: .seconds(0.55))
                if Task.isCancelled { return }
            }
        }
    }
}

private struct GlyphStroke: Shape {
    let path: Path

    func path(in rect: CGRect) -> Path {
        path.applying(CGAffineTransform(
            scaleX: rect.width / CharacterStrokes.canvasSize,
            y: rect.height / CharacterStrokes.canvasSize
        ))
    }
}
