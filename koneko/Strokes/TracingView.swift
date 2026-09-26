import SwiftUI

/// Practice mode: she writes the character stroke by stroke (Apple Pencil, finger or mouse)
/// and each stroke is checked for order, direction and shape.
struct TracingView: View {
    let data: CharacterStrokes

    @AppStorage("tracingGuide") private var showGuide = true

    @State private var paths: [Path] = []
    @State private var references: [[CGPoint]] = []
    /// Her accepted strokes, in KanjiVG's 109×109 space.
    @State private var accepted: [[CGPoint]] = []
    @State private var current: [CGPoint] = []
    @State private var mistakes = 0
    @State private var message: Message?
    /// A stroke being demonstrated after a mistake (or when she asks "Show me").
    @State private var demoIndex: Int?
    @State private var demoProgress: CGFloat = 0
    @State private var demoTask: Task<Void, Never>?

    private struct Message: Equatable {
        let text: String
        let isGood: Bool
    }

    private var nextIndex: Int { accepted.count }
    private var isFinished: Bool { !paths.isEmpty && accepted.count >= paths.count }
    private var tolerance: CGFloat { showGuide ? 14 : 19 }

    var body: some View {
        VStack(spacing: 14) {
            canvas
            feedback
            controls
        }
        .task {
            paths = data.strokes.map(SVGPath.parse)
            references = paths.map(StrokeMatcher.samples)
        }
        .onDisappear { demoTask?.cancel() }
        .sensoryFeedback(.success, trigger: accepted.count)
        .sensoryFeedback(.error, trigger: mistakes)
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let scale = side / CharacterStrokes.canvasSize
            let style = StrokeStyle(lineWidth: max(5, side * 0.036), lineCap: .round, lineJoin: .round)

            ZStack(alignment: .topLeading) {
                PracticeGrid()

                if showGuide {
                    ForEach(paths.indices, id: \.self) { index in
                        ReferenceStroke(path: paths[index])
                            .stroke(Color.secondary.opacity(0.2), style: style)
                    }
                }

                ForEach(accepted.indices, id: \.self) { index in
                    InkStroke(points: accepted[index])
                        .stroke(isFinished ? Color.green : Color.primary, style: style)
                }

                if let demoIndex, paths.indices.contains(demoIndex) {
                    ReferenceStroke(path: paths[demoIndex])
                        .trim(from: 0, to: demoProgress)
                        .stroke(Color.orange, style: style)
                }

                InkStroke(points: current)
                    .stroke(Color.blue, style: style)

                if let start = nextStartPoint {
                    Circle()
                        .fill(Color.green)
                        .frame(width: side * 0.05, height: side * 0.05)
                        .overlay(
                            Text("\(nextIndex + 1)")
                                .font(.system(size: side * 0.03, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        )
                        .position(x: start.x * scale, y: start.y * scale)
                        .allowsHitTesting(false)
                }

                if isFinished {
                    Text("⭐️")
                        .font(.system(size: side * 0.2))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(side * 0.03)
                        .transition(.scale)
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !isFinished else { return }
                        let point = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                        if current.isEmpty {
                            demoTask?.cancel()
                            demoIndex = nil
                        }
                        current.append(point)
                    }
                    .onEnded { _ in strokeEnded() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 480)
        .accessibilityLabel("Writing area")
    }

    /// Green dot where the next stroke starts: always with the guide, otherwise after a mistake.
    private var nextStartPoint: CGPoint? {
        guard !isFinished, current.isEmpty, references.indices.contains(nextIndex) else { return nil }
        guard showGuide || message?.isGood == false else { return nil }
        return references[nextIndex].first
    }

    // MARK: Feedback and controls

    private var feedback: some View {
        Group {
            if isFinished {
                Text(finishedText)
                    .foregroundStyle(.green)
            } else if let message {
                Text(message.text)
                    .foregroundStyle(message.isGood ? Color.green : Color.orange)
            } else {
                Text("Write stroke \(nextIndex + 1) of \(paths.count)")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.headline)
        .multilineTextAlignment(.center)
        .frame(minHeight: 44)
        .animation(.default, value: message)
    }

    private var finishedText: String {
        switch mistakes {
        case 0: "Perfect! ⭐️⭐️⭐️ よくできました!"
        case 1...2: "Well done! ⭐️⭐️ よくできました!"
        default: "You did it! ⭐️ Try again for more stars."
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button("Show me", systemImage: "eye") { demonstrate(nextIndex) }
                .disabled(isFinished)
            Button("Undo", systemImage: "arrow.uturn.backward") {
                if !accepted.isEmpty { accepted.removeLast() }
                message = nil
            }
            .disabled(accepted.isEmpty || isFinished)
            Button("Start over", systemImage: "arrow.counterclockwise", action: reset)
            Toggle("Guide", isOn: $showGuide)
                .toggleStyle(.button)
        }
        .buttonStyle(.bordered)
    }

    // MARK: Logic

    private func strokeEnded() {
        let drawn = current
        current = []
        guard !isFinished else { return }

        switch StrokeMatcher.evaluate(drawn: drawn, expectedIndex: nextIndex, references: references, tolerance: tolerance) {
        case .correct:
            accepted.append(drawn)
            message = isFinished ? nil : Message(text: ["Good!", "Great!", "Nice!", "👍"].randomElement()!, isGood: true)
            if isFinished {
                Pronouncer.shared.speak("よくできました")
            }
        case .reversed:
            mistake("Almost! Start from the other end.")
        case .wrongOrder(let index):
            mistake("That's stroke \(index + 1). First draw stroke \(nextIndex + 1).")
        case .tooFar:
            mistake(showGuide ? "Try again, follow the grey line." : "Try again. Watch how it goes.")
        case .tooShort:
            break
        }
    }

    private func mistake(_ text: String) {
        mistakes += 1
        message = Message(text: text, isGood: false)
        demonstrate(nextIndex)
    }

    /// Animates the stroke at `index` in orange, then hides it again.
    private func demonstrate(_ index: Int) {
        guard paths.indices.contains(index) else { return }
        demoTask?.cancel()
        demoIndex = index
        demoProgress = 0
        demoTask = Task {
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.9)) { demoProgress = 1 }
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { demoIndex = nil }
        }
    }

    private func reset() {
        demoTask?.cancel()
        demoIndex = nil
        accepted = []
        current = []
        mistakes = 0
        message = nil
    }
}

/// A KanjiVG stroke scaled from 109×109 to the available rect.
private struct ReferenceStroke: Shape {
    let path: Path

    func path(in rect: CGRect) -> Path {
        path.applying(CGAffineTransform(
            scaleX: rect.width / CharacterStrokes.canvasSize,
            y: rect.height / CharacterStrokes.canvasSize
        ))
    }
}

/// A stroke she drew, stored in 109×109 space.
private struct InkStroke: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / CharacterStrokes.canvasSize
        let scaleY = rect.height / CharacterStrokes.canvasSize
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x * scaleX, y: first.y * scaleY))
        if points.count == 1 {
            path.addLine(to: CGPoint(x: first.x * scaleX + 0.1, y: first.y * scaleY))
        }
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x * scaleX, y: point.y * scaleY))
        }
        return path
    }
}
