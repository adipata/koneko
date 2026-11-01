#if os(iOS)
import SwiftUI
import UIKit

/// Text she can select part of (touch and hold, then drag the handles) to copy it, like in
/// Notes. SwiftUI's `.textSelection` only copies the whole text on iPhone and iPad.
/// The edit menu also offers "Look up in Write" for the selected words.
struct SelectableText: UIViewRepresentable {
    let text: String
    var textStyle: UIFont.TextStyle = .body
    var weight: UIFont.Weight = .regular
    var color: UIColor = .label
    var onLookUp: ((String) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.dataDetectorTypes = []
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        // The style's size at the default text size, scaled with her Dynamic Type setting.
        let defaultSize = UIFont.preferredFont(
            forTextStyle: textStyle,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
        ).pointSize
        let font = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: .systemFont(ofSize: defaultSize, weight: weight))
        if view.text != text { view.text = text }
        view.font = font
        view.textColor = color
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else {
            let size = uiView.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
            return CGSize(width: ceil(size.width), height: ceil(size.height))
        }
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableText

        init(parent: SelectableText) {
            self.parent = parent
        }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard let onLookUp = parent.onLookUp,
                  let swiftRange = Range(range, in: textView.text) else { return nil }
            let selected = String(textView.text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selected.isEmpty, selected.count <= 40 else { return nil }
            let lookUp = UIAction(title: "Look up in Write", image: UIImage(systemName: "pencil.and.scribble")) { _ in
                onLookUp(selected)
            }
            return UIMenu(children: suggestedActions + [lookUp])
        }
    }
}
#endif
