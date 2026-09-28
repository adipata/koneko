import SwiftUI

/// About Koneko: mascot, version, what the app does, privacy and credits.
struct AboutView: View {
    @State private var showCredits = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .padding(20)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.80, blue: 0.47), Color(red: 1.0, green: 0.50, blue: 0.45)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    )

                VStack(spacing: 4) {
                    Text("Koneko")
                        .font(.handwriting(size: 44))
                    Text("こねこ ・ kitten")
                        .font(.handwriting(size: 18))
                        .foregroundStyle(.secondary)
                    Text(AppInfo.versionText)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .textSelection(.enabled)
                }

                Text("Learn to write Japanese, one little stroke at a time.")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    feature("mic.fill", "Say or type a word in English or Japanese")
                    feature("character.book.closed", "See it in kanji, hiragana or katakana, with furigana")
                    feature("pencil.tip", "Watch the stroke order, then practise with Apple Pencil")
                    feature("speaker.wave.2.fill", "Hear how it sounds")
                    feature("book", "Keep your words in folders, on iPad, Mac and Apple Watch")
                }
                .padding()
                .frame(maxWidth: 480, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.08)))

                VStack(alignment: .leading, spacing: 6) {
                    Label("Privacy", systemImage: "hand.raised.fill")
                        .font(.headline)
                    Text("Speech is recognised on the device whenever possible. Only the words you look up are sent to the AI service you choose (through OpenRouter) to translate and explain them. Your word list stays on your devices and in your own iCloud.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 480, alignment: .leading)

                Button("Credits & licenses", systemImage: "heart.text.square") { showCredits = true }
                    .buttonStyle(.bordered)

                Text("Made with ❤️ for young learners of Japanese\n© \(Calendar.current.component(.year, from: .now).formatted(.number.grouping(.never))) Koneko")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("About")
        .sheet(isPresented: $showCredits) { CreditsView() }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.orange)
                .frame(width: 26)
        }
    }
}
