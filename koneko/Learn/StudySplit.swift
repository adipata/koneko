import SwiftUI

/// Chart/grid on one side, the selected character on the other (iPad, Mac, iPhone landscape);
/// on a narrow screen (iPhone portrait) the character opens in a sheet instead.
struct StudySplit<Item: Identifiable, Browser: View, Detail: View>: View {
    @Binding var selection: Item?
    let placeholder: String
    @ViewBuilder let browser: () -> Browser
    @ViewBuilder let detail: (Item) -> Detail

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isCompact: Bool { sizeClass == .compact }
    #else
    private var isCompact: Bool { false }
    #endif

    var body: some View {
        if isCompact {
            ScrollView {
                browser()
                    .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .sheet(item: $selection) { item in
                NavigationStack {
                    ScrollView {
                        detail(item)
                            .padding()
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { selection = nil }
                        }
                    }
                }
                .presentationDetents([.large])
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                ScrollView {
                    browser()
                        .padding()
                }
                .scrollDismissesKeyboard(.immediately)
                .frame(maxWidth: .infinity)
                Divider()
                ScrollView {
                    if let item = selection {
                        detail(item)
                            .padding()
                            .id(item.id)
                    } else {
                        ContentUnavailableView(placeholder, systemImage: "hand.tap")
                            .padding(.top, 80)
                    }
                }
                .frame(minWidth: 340, idealWidth: 440, maxWidth: 500)
            }
        }
    }
}
