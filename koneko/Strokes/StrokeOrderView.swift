import SwiftUI

/// Shows one character on a practice grid and animates its strokes in order.
struct StrokeOrderView: View {
    let data: CharacterStrokes

    @AppStorage("strokeSpeed") private var speed = 1.0
    @AppStorage("showStrokeNumbers") private var showNumbers = true

    @State private var paths: [Path] = []
    /// Number of strokes that are completely drawn.
    @State private var drawn = 0
    /// How much of stroke number `drawn` is visible (0...1).
    @State private var progress: CGFloat = 0
    @State private var isPlaying = false
    @State private var playTask: Task<Void, Never>?

    private var strokeDuration: Double { 0.7 / speed }
    private var isFinished: Bool { drawn >= paths.count }

    var body: some View {
        VStack(spacing: 16) {
            canvas
            Text(isFinished ? "\(paths.count) strokes" : "Stroke \(drawn + 1) of \(paths.count)")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            controls
        }
        .task {
            paths = data.strokes.map(SVGPath.parse)
            play()
        }
        .onDisappear { playTask?.cancel() }
    }

    // MARK: Drawing

    private var canvas: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let scale = side / CharacterStrokes.canvasSize
            let style = StrokeStyle(lineWidth: max(4, side * 0.032), lineCap: .round, lineJoin: .round)

            ZStack(alignment: .topLeading) {
                PracticeGrid()

                // Faint guide of the whole character.
                ForEach(paths.indices, id: \.self) { index in
                    StrokeShape(path: paths[index])
                        .stroke(Color.secondary.opacity(0.18), style: style)
                }

                ForEach(paths.indices, id: \.self) { index in
                    StrokeShape(path: paths[index])
                        .trim(from: 0, to: visibleFraction(of: index))
                        .stroke(index == drawn ? Color.orange : Color.primary, style: style)
                }

                if showNumbers {
                    ForEach(Array(data.numberPositions.enumerated()), id: \.offset) { index, position in
                        if index <= drawn {
                            Text("\(index + 1)")
                                .font(.system(size: side * 0.065, weight: .bold, design: .rounded))
                                .foregroundStyle(index == drawn ? Color.orange : Color.blue)
                                .position(x: (position.x + 2.5) * scale, y: (position.y - 3) * scale)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 480)
        .accessibilityLabel("Stroke order animation")
    }

    private func visibleFraction(of index: Int) -> CGFloat {
        if index < drawn { return 1 }
        if index == drawn { return progress }
        return 0
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 28) {
                Button("Previous stroke", systemImage: "backward.end.fill", action: stepBack)
                    .disabled(drawn == 0)
                Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill") {
                    isPlaying ? pause() : play()
                }
                .font(.largeTitle)
                Button("Next stroke", systemImage: "forward.end.fill", action: stepForward)
                    .disabled(isFinished)
                Button("Start over", systemImage: "arrow.counterclockwise", action: restart)
            }
            .labelStyle(.iconOnly)
            .font(.title2)

            HStack {
                Picker("Speed", selection: $speed) {
                    Text("🐢 Slow").tag(0.5)
                    Text("Normal").tag(1.0)
                    Text("🐇 Fast").tag(2.0)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                Toggle("Numbers", isOn: $showNumbers)
                    .toggleStyle(.button)
            }
        }
    }

    // MARK: Playback

    private func play() {
        if isFinished { reset() }
        run(strokeCount: paths.count - drawn)
    }

    private func pause() {
        playTask?.cancel()
        isPlaying = false
        if progress > 0 { completeCurrentStroke() }
    }

    private func restart() {
        pause()
        reset()
        play()
    }

    private func stepForward() {
        pause()
        run(strokeCount: 1)
    }

    private func stepBack() {
        pause()
        withoutAnimation {
            drawn = max(0, drawn - 1)
            progress = 0
        }
    }

    private func reset() {
        withoutAnimation {
            drawn = 0
            progress = 0
        }
    }

    /// Animates the next `strokeCount` strokes, one after another.
    private func run(strokeCount: Int) {
        playTask?.cancel()
        guard strokeCount > 0 else { return }
        isPlaying = true
        playTask = Task {
            for _ in 0..<strokeCount where !isFinished {
                let duration = strokeDuration
                withAnimation(.easeInOut(duration: duration)) { progress = 1 }
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                completeCurrentStroke()
                try? await Task.sleep(for: .seconds(0.3 / speed))
                guard !Task.isCancelled else { return }
            }
            isPlaying = false
        }
    }

    private func completeCurrentStroke() {
        withoutAnimation {
            drawn = min(drawn + 1, paths.count)
            progress = 0
        }
    }

    private func withoutAnimation(_ changes: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, changes)
    }
}

/// A single stroke, scaled from KanjiVG's 109×109 space to the available rect.
private struct StrokeShape: Shape {
    let path: Path

    func path(in rect: CGRect) -> Path {
        let scale = CGAffineTransform(
            scaleX: rect.width / CharacterStrokes.canvasSize,
            y: rect.height / CharacterStrokes.canvasSize
        )
        return path.applying(scale)
    }
}

/// The square writing box with a dashed cross, like Japanese practice paper.
struct PracticeGrid: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.5, opacity: 0.06))
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 2)
                Path { path in
                    path.move(to: CGPoint(x: size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                }
                .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
            }
        }
    }
}
