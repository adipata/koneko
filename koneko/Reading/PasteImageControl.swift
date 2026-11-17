#if os(iOS)
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The system paste button (no "Allow Paste" question) for pictures, as a round icon button.
/// Unlike SwiftUI's `PasteButton`, `UIPasteControl` takes any size, so it can match the
/// buttons next to it.
struct PasteImageControl: UIViewRepresentable {
    var tint: UIColor = .systemOrange
    let onPaste: ([NSItemProvider]) -> Void

    func makeUIView(context: Context) -> PasteTarget {
        let target = PasteTarget()
        target.onPaste = onPaste
        target.pasteConfiguration = UIPasteConfiguration(acceptableTypeIdentifiers: [UTType.image.identifier])

        // A class, so its properties can be set on a constant.
        let configuration = UIPasteControl.Configuration()
        configuration.displayMode = .iconOnly
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = tint
        configuration.baseForegroundColor = .white
        let control = UIPasteControl(configuration: configuration)
        control.target = target
        control.translatesAutoresizingMaskIntoConstraints = false
        target.addSubview(control)
        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: target.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: target.trailingAnchor),
            control.topAnchor.constraint(equalTo: target.topAnchor),
            control.bottomAnchor.constraint(equalTo: target.bottomAnchor),
        ])
        return target
    }

    func updateUIView(_ target: PasteTarget, context: Context) {
        target.onPaste = onPaste
    }

    /// Receives what the paste control pastes.
    final class PasteTarget: UIView {
        var onPaste: (([NSItemProvider]) -> Void)?

        override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
            itemProviders.contains { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        }

        override func paste(itemProviders: [NSItemProvider]) {
            onPaste?(itemProviders)
        }
    }
}
#endif
