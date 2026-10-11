#if os(iOS)
import PhotosUI
import SwiftUI
import UIKit

/// The 📷 button on Write: take or choose a photo, then pick the words in it.
struct PhotoTextButton: View {
    let settings: AppSettings
    let onText: (String) -> Void
    let openSettings: () -> Void

    @State private var showsCamera = false
    @State private var showsLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    /// The photo just taken, shown once the camera has closed.
    @State private var takenPhoto: UIImage?
    @State private var photo: PickedPhoto?

    var body: some View {
        Menu {
            if CameraPicker.isAvailable {
                Button("Take a photo", systemImage: "camera") { showsCamera = true }
            }
            Button("Choose a photo", systemImage: "photo.on.rectangle") { showsLibrary = true }
        } label: {
            Image(systemName: "camera")
                .font(.title3.weight(.semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .accessibilityLabel("Words from a photo")
        .help("Words from a photo")
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
            PhotoTextView(image: photo.image, model: settings.imageModel, onText: onText, openSettings: openSettings)
        }
    }

    private func showTakenPhoto() {
        guard let takenPhoto else { return }
        self.takenPhoto = nil
        photo = PickedPhoto(image: takenPhoto)
    }

    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        photo = PickedPhoto(image: image)
    }
}

private struct PickedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}
#endif
