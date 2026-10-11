#if os(iOS)
import SwiftUI
import UIKit

/// The photo with a frame she can move and resize, to keep only the words she wants.
/// `cropRect` is in 0…1 of the photo.
struct PhotoCropView: View {
    let image: UIImage
    @Binding var cropRect: CGRect

    /// The frame when the current drag started.
    @State private var dragStart: CGRect?

    private static let minimumSize: CGFloat = 0.05

    var body: some View {
        GeometryReader { geometry in
            let shown = fittedRect(in: geometry.size)
            let frame = CGRect(
                x: shown.minX + cropRect.minX * shown.width,
                y: shown.minY + cropRect.minY * shown.height,
                width: cropRect.width * shown.width,
                height: cropRect.height * shown.height
            )
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: shown.width, height: shown.height)
                    .position(x: shown.midX, y: shown.midY)

                // Dim everything outside the frame.
                Path { path in
                    path.addRect(shown)
                    path.addRect(frame)
                }
                .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .contentShape(Rectangle())
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .gesture(dragGesture(in: shown) { start, dx, dy in
                        start.offsetBy(dx: dx, dy: dy)
                    })

                ForEach(Corner.allCases, id: \.self) { corner in
                    handle
                        .position(corner.point(in: frame))
                        .gesture(dragGesture(in: shown) { start, dx, dy in
                            corner.resize(start, dx: dx, dy: dy, minimum: Self.minimumSize)
                        })
                }
            }
        }
        .accessibilityLabel("Photo with a frame around the words to read")
    }

    private var handle: some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(Color.orange, lineWidth: 3))
            .frame(width: 26, height: 26)
            .shadow(radius: 2)
            .frame(width: 48, height: 48)
            .contentShape(Rectangle())
    }

    /// Where the photo sits when fitted into `size`.
    private func fittedRect(in size: CGSize) -> CGRect {
        let scale = min(size.width / max(image.size.width, 1), size.height / max(image.size.height, 1))
        let width = image.size.width * scale
        let height = image.size.height * scale
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    private func dragGesture(in shown: CGRect, change: @escaping (CGRect, CGFloat, CGFloat) -> CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? cropRect
                dragStart = start
                let dx = value.translation.width / max(shown.width, 1)
                let dy = value.translation.height / max(shown.height, 1)
                cropRect = Self.keptInside(change(start, dx, dy))
            }
            .onEnded { _ in dragStart = nil }
    }

    /// Moves the frame back inside the photo (0…1).
    private static func keptInside(_ rect: CGRect) -> CGRect {
        var rect = rect
        rect.size.width = min(max(rect.width, minimumSize), 1)
        rect.size.height = min(max(rect.height, minimumSize), 1)
        rect.origin.x = min(max(rect.minX, 0), 1 - rect.width)
        rect.origin.y = min(max(rect.minY, 0), 1 - rect.height)
        return rect
    }

    private enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        func point(in rect: CGRect) -> CGPoint {
            switch self {
            case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
            case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
            case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
            case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            }
        }

        /// The frame with this corner dragged, the opposite corner staying put.
        func resize(_ rect: CGRect, dx: CGFloat, dy: CGFloat, minimum: CGFloat) -> CGRect {
            var minX = rect.minX, minY = rect.minY, maxX = rect.maxX, maxY = rect.maxY
            switch self {
            case .topLeft: minX += dx; minY += dy
            case .topRight: maxX += dx; minY += dy
            case .bottomLeft: minX += dx; maxY += dy
            case .bottomRight: maxX += dx; maxY += dy
            }
            minX = max(0, min(minX, maxX - minimum))
            minY = max(0, min(minY, maxY - minimum))
            maxX = min(1, max(maxX, minX + minimum))
            maxY = min(1, max(maxY, minY + minimum))
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }
}
#endif
