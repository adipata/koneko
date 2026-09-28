import SwiftUI

/// The launch splash: the kitten mascot bounces in under falling sakura petals.
/// Tap to skip; with Reduce Motion it simply fades in and out.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var bounce = false
    @State private var petals = (0..<16).map { _ in Petal.random() }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.80, blue: 0.47), Color(red: 1.0, green: 0.50, blue: 0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if !reduceMotion {
                GeometryReader { geometry in
                    ForEach(petals) { petal in
                        Text("🌸")
                            .font(.system(size: petal.size))
                            .rotationEffect(.degrees(appeared ? petal.spin : 0))
                            .position(
                                x: petal.x * geometry.size.width + (appeared ? petal.drift : 0),
                                y: appeared ? geometry.size.height + 60 : -60 - petal.delay * 120
                            )
                            .animation(.linear(duration: petal.duration).delay(petal.delay), value: appeared)
                    }
                }
                .ignoresSafeArea()
            }

            VStack(spacing: 14) {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260, maxHeight: 260)
                    .scaleEffect(appeared ? 1 : 0.3)
                    .rotationEffect(.degrees(reduceMotion ? 0 : (bounce ? -4 : 4)))
                    .offset(y: reduceMotion ? 0 : (bounce ? -8 : 8))
                Text("Koneko")
                    .font(.handwriting(size: 58))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                Text("こねこ ・ learn to write Japanese")
                    .font(.handwriting(size: 20))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .opacity(appeared ? 1 : 0)
            .padding()
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeIn(duration: 0.3) : .spring(response: 0.6, dampingFraction: 0.55)) {
                appeared = true
            }
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    bounce = true
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Koneko")
    }

    private struct Petal: Identifiable {
        let id = UUID()
        let x: CGFloat
        let drift: CGFloat
        let size: CGFloat
        let spin: Double
        let duration: Double
        let delay: Double

        static func random() -> Petal {
            Petal(
                x: .random(in: 0.02...0.98),
                drift: .random(in: -60...60),
                size: .random(in: 16...30),
                spin: .random(in: -240...240),
                duration: .random(in: 2.2...3.4),
                delay: .random(in: 0...0.8)
            )
        }
    }
}

/// App name, version and build from the bundle.
enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var versionText: String { "Version \(version) (\(build))" }
}
