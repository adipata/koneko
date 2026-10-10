import SwiftUI

/// Under the word on the Write screen: pin it or put it in a folder of My words right away.
struct SaveWordBar: View {
    let history: HistoryStore
    let word: WordCandidate

    @State private var showNewFolder = false
    @State private var folderName = ""

    private var entry: HistoryEntry? {
        history.entries.first { $0.id == word.id }
    }

    private var isPinned: Bool { entry?.isPinned ?? false }

    private var folder: WordFolder? {
        guard let id = entry?.folderID else { return nil }
        return history.folders.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                ensureSaved()
                history.setPinned([word.id], !isPinned)
            } label: {
                Label(isPinned ? "Pinned" : "Pin", systemImage: isPinned ? "pin.fill" : "pin")
            }
            .tint(isPinned ? .orange : .secondary)

            Menu {
                ForEach(history.folders) { item in
                    Button {
                        move(to: item)
                    } label: {
                        if item.id == folder?.id {
                            Label(item.name, systemImage: "checkmark")
                        } else {
                            Text(item.name)
                        }
                    }
                }
                Divider()
                Button("New folder…", systemImage: "folder.badge.plus") {
                    folderName = ""
                    showNewFolder = true
                }
                if folder != nil {
                    Button("No folder", systemImage: "folder.badge.minus") { move(to: nil) }
                }
            } label: {
                Label(folder?.name ?? "Add to folder", systemImage: folder == nil ? "folder.badge.plus" : "folder.fill")
                    .lineLimit(1)
            }
            .tint(folder == nil ? .secondary : .orange)
        }
        .font(.callout.weight(.semibold))
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .alert("New folder", isPresented: $showNewFolder) {
            TextField("e.g. 🐾 Animals", text: $folderName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                if let created = history.createFolder(named: folderName) {
                    move(to: created)
                }
            }
        } message: {
            Text("This word goes into the new folder.")
        }
    }

    private func move(to folder: WordFolder?) {
        ensureSaved()
        history.move([word.id], to: folder)
    }

    /// The word is normally already in My words; this is only a safety net.
    private func ensureSaved() {
        if entry == nil {
            history.record(word)
        }
    }
}
