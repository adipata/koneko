#if os(iOS)
import SwiftUI
import UIKit
import VisionKit

/// A photo with Apple's Live Text on top: the printed text in it can be selected like in
/// Photos (touch and hold, then drag the handles). Recognition runs on the device.
struct LiveTextImage: UIViewRepresentable {
    let image: UIImage
    let analysis: ImageAnalysis?
    /// The text selected right now (empty when nothing is selected).
    @Binding var selectedText: String

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        view.isUserInteractionEnabled = true
        // Let SwiftUI decide the size instead of the photo's pixel size.
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)

        let interaction = ImageAnalysisInteraction()
        interaction.delegate = context.coordinator
        view.addInteraction(interaction)
        context.coordinator.interaction = interaction
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        context.coordinator.parent = self
        // The analysis arrives once, after the photo is shown.
        guard let analysis, !context.coordinator.hasAnalysis, let interaction = context.coordinator.interaction else { return }
        context.coordinator.hasAnalysis = true
        interaction.analysis = analysis
        interaction.preferredInteractionTypes = .textSelection
        // Show which text can be picked.
        interaction.selectableItemsHighlighted = true
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        let available = proposal.replacingUnspecifiedDimensions(by: image.size)
        let fit = min(available.width / max(image.size.width, 1), available.height / max(image.size.height, 1))
        return CGSize(width: image.size.width * fit, height: image.size.height * fit)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, ImageAnalysisInteractionDelegate {
        var parent: LiveTextImage
        var interaction: ImageAnalysisInteraction?
        var hasAnalysis = false

        init(parent: LiveTextImage) {
            self.parent = parent
        }

        func textSelectionDidChange(_ interaction: ImageAnalysisInteraction) {
            parent.selectedText = interaction.selectedText
        }
    }
}
#endif
