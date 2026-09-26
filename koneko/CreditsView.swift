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
            }
            .navigationTitle("Credits")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}
