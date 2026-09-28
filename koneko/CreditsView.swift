import SwiftUI

struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Stroke order data") {
                    Text("Stroke order data comes from KanjiVG, copyright © Ulrich Apel, and is used under the Creative Commons Attribution-Share Alike 3.0 license.")
                    Link("kanjivg.tagaini.net", destination: URL(string: "https://kanjivg.tagaini.net")!)
                    Link("CC BY-SA 3.0 license", destination: URL(string: "https://creativecommons.org/licenses/by-sa/3.0/")!)
                }
                Section("Kanji data") {
                    Text("Kanji grade levels, meanings and readings come from KANJIDIC2, copyright © the Electronic Dictionary Research and Development Group, used under the Creative Commons Attribution-Share Alike 4.0 license, via the kanji-data project by David Luz Gouveia.")
                    Link("edrdg.org/kanjidic", destination: URL(string: "https://www.edrdg.org/wiki/index.php/KANJIDIC_Project")!)
                }
                Section("Font") {
                    Text("Klee One by Fontworks, used under the SIL Open Font License 1.1.")
                    Link("github.com/fontworks-fonts/Klee", destination: URL(string: "https://github.com/fontworks-fonts/Klee")!)
                }
            }
            .navigationTitle("Credits")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 260)
            #endif
        }
    }
}
