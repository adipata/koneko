import SwiftUI

/// The round tick shown on symbols in Select mode, like in the Photos app.
struct SelectionCheckmark: View {
    let isChecked: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isChecked ? Color.accentColor : Color.black.opacity(0.15))
            Circle()
                .strokeBorder(.white, lineWidth: 1.5)
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 20, height: 20)
        .shadow(color: .black.opacity(0.2), radius: 1)
        .padding(4)
        .accessibilityHidden(true)
    }
}
