#if os(iOS)
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The Reading section: her books and manga. Each reading keeps the parts she scanned, so the
/// AI can explain the next ones knowing what came before.
struct ReadingsView: View {
    let model: AppModel

    @State private var path: [ReadingRoute] = []
    @State private var showsNewReading = false
    @State private var renaming: Reading?
    @State private var newTitle = ""
    @State private var deleting: Reading?

    private var store: ReadingStore { model.readings }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.readings.isEmpty {
                    ContentUnavailableView {
                        Label("No readings yet", systemImage: "book.pages")
                    } description: {
                        Text("Start a reading for each book or manga. Take a photo of a page, or paste a screenshot, and Koneko explains the Japanese, remembering what you read before.")
                    } actions: {
                        Button("New reading", systemImage: "plus") { showsNewReading = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Reading")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New reading", systemImage: "plus") { showsNewReading = true }
                }
            }
            .navigationDestination(for: ReadingRoute.self) { route in
                switch route {
                case .reading(let id):
                    ReadingDetailView(model: model, readingID: id)
                case .entry(let readingID, let entryID):
                    if let entry = store.reading(readingID)?.entries.first(where: { $0.id == entryID }) {
                        ReadingEntryView(entry: entry, history: model.history) { model.lookUp($0) }
                    } else {
                        ContentUnavailableView("This part was deleted", systemImage: "text.viewfinder")
                    }
                }
            }
        }
        .sheet(isPresented: $showsNewReading) {
            NewReadingSheet { title, kind in
                let reading = store.create(title: title, kind: kind)
                path = [.reading(reading.id)]
            }
        }
        .alert("Rename reading", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let renaming { store.rename(renaming.id, to: newTitle) }
            }
        }
        .confirmationDialog(
            "Delete “\(deleting?.title ?? "")”?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete reading", role: .destructive) {
                if let deleting { store.delete(deleting.id) }
            }
        } message: {
            Text("Its history and explanations will be deleted too.")
        }
    }

    private var list: some View {
        List {
            ForEach(store.readings) { reading in
                NavigationLink(value: ReadingRoute.reading(reading.id)) {
                    HStack(spacing: 12) {
                        Text(reading.kind.emoji)
                            .font(.title)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reading.title)
                                .font(.headline)
                            Text(summary(of: reading))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = reading }
                }
                .contextMenu {
                    Button("Rename", systemImage: "pencil") {
                        newTitle = reading.title
                        renaming = reading
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = reading }
                }
            }
        }
    }

    private func summary(of reading: Reading) -> String {
        let parts = reading.entries.count
        let count = parts == 0 ? "Nothing scanned yet" : parts == 1 ? "1 part" : "\(parts) parts"
        return "\(reading.kind.name) · \(count) · \(reading.updated.formatted(.relative(presentation: .named)))"
    }
}

/// Pages of the Reading section. Only value-based links, in one `NavigationStack(path:)`.
enum ReadingRoute: Hashable {
    case reading(Reading.ID)
    case entry(reading: Reading.ID, entry: ReadingEntry.ID)
}

/// Asks for the title and whether it's a book or a manga.
private struct NewReadingSheet: View {
    let onCreate: (String, ReadingKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var kind = ReadingKind.manga
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title (e.g. よつばと! 1)", text: $title)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit(create)
                }
                Section {
                    Picker("Kind", selection: $kind) {
                        ForEach(ReadingKind.allCases) { kind in
                            Text("\(kind.emoji) \(kind.name)").tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(kind == .manga
                         ? "For a manga, crop one panel at a time: Koneko also looks at the picture to understand the story."
                         : "For a book, select the sentences in the photo, or crop them.")
                }
            }
            .navigationTitle("New reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { titleFocused = true }
    }

    private func create() {
        onCreate(title, kind)
        dismiss()
    }
}

/// One reading: buttons to scan a new part, and the history of the parts already explained.
struct ReadingDetailView: View {
    let model: AppModel
    let readingID: Reading.ID

    @Environment(\.dismiss) private var dismiss
    @State private var showsCamera = false
    @State private var showsLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var takenPhoto: UIImage?
    @State private var photo: ScanPhoto?
    @State private var confirmsDelete = false
    @State private var renaming = false
    @State private var newTitle = ""

    private var store: ReadingStore { model.readings }

    var body: some View {
        if let reading = store.reading(readingID) {
            content(reading)
        } else {
            ContentUnavailableView("This reading was deleted", systemImage: "book.pages")
        }
    }

    private func content(_ reading: Reading) -> some View {
        List {
            Section {
                scanButtons
            } footer: {
                Text(reading.kind == .manga
                     ? "Tip: on the same device, take a screenshot of the page, then choose or paste it."
                     : "Tip: reading on this device? Take a screenshot, then choose or paste it.")
            }

            Section(reading.entries.isEmpty ? "" : "History") {
                if reading.entries.isEmpty {
                    Text("The parts you scan will be listed here, so you can read their explanation again.")
                        .foregroundStyle(.secondary)
                }
                // Newest first.
                ForEach(reading.entries.reversed()) { entry in
                    NavigationLink(value: ReadingRoute.entry(reading: readingID, entry: entry.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.text)
                                .font(.title3)
                                .lineLimit(3)
                            Label(
                                entry.date.formatted(date: .abbreviated, time: .shortened),
                                systemImage: entry.source == .picture ? "crop" : "text.viewfinder"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .swipeActions {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            store.deleteEntry(entry.id, from: readingID)
                        }
                    }
                    .contextMenu {
                        Button("Copy text", systemImage: "doc.on.doc") { Clipboard.copy(entry.text) }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            store.deleteEntry(entry.id, from: readingID)
                        }
                    }
                }
            }
        }
        .navigationTitle("\(reading.kind.emoji) \(reading.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Rename", systemImage: "pencil") {
                        newTitle = reading.title
                        renaming = true
                    }
                    Button("Delete reading", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                }
            }
        }
        .fullScreenCover(isPresented: $showsCamera, onDismiss: showTakenPhoto) {
            CameraPicker { takenPhoto = $0 }
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showsLibrary, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) {
            guard let item = libraryItem else { return }
            libraryItem = nil
            Task { await load(item) }
        }
        .sheet(item: $photo) { photo in
            ReadingScanView(
                image: photo.image,
                reading: reading,
                store: store,
                history: model.history,
                model: model.settings.imageModel,
                openSettings: { model.section = .settings },
                onLookUp: lookUp
            )
        }
        .alert("Rename reading", isPresented: $renaming) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) {}
            Button("Rename") { store.rename(readingID, to: newTitle) }
        }
        .confirmationDialog("Delete “\(reading.title)”?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete reading", role: .destructive) {
                dismiss()
                store.delete(readingID)
            }
        } message: {
            Text("Its history and explanations will be deleted too.")
        }
    }

    /// Round icon buttons with a small caption below, like the share sheet. The system Paste
    /// button (no "Allow Paste" question) can't stack its own label, so every caption is a
    /// separate text under an icon-only button.
    private var scanButtons: some View {
        HStack(alignment: .top, spacing: 12) {
            if CameraPicker.isAvailable {
                scanTile("Photo") {
                    Button("Take a photo", systemImage: "camera.fill") { showsCamera = true }
                }
            }
            scanTile("Choose") {
                Button("Choose a photo", systemImage: "photo.on.rectangle") { showsLibrary = true }
            }
            scanTile("Paste") {
                PasteButton(supportedContentTypes: [.image]) { providers in
                    paste(providers)
                }
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .controlSize(.extraLarge)
        .tint(.orange)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func scanTile(_ caption: String, @ViewBuilder button: () -> some View) -> some View {
        VStack(spacing: 6) {
            button()
            Text(caption)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                // VoiceOver already reads the button's own title.
                .accessibilityHidden(true)
        }
        .frame(maxWidth: 96)
        .frame(maxWidth: .infinity)
    }

    private func lookUp(_ text: String) {
        model.lookUp(text)
    }

    private func showTakenPhoto() {
        guard let takenPhoto else { return }
        self.takenPhoto = nil
        photo = ScanPhoto(image: takenPhoto)
    }

    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        photo = ScanPhoto(image: image)
    }

    private func paste(_ providers: [NSItemProvider]) {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else { return }
        _ = provider.loadDataRepresentation(for: .image) { data, _ in
            guard let data else { return }
            Task { @MainActor in
                if let image = UIImage(data: data) {
                    photo = ScanPhoto(image: image)
                }
            }
        }
    }
}

private struct ScanPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}
#endif
