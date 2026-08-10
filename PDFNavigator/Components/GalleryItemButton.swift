import SwiftUI

/// A Gallery item opens on a pointer double-click.
///
/// Assistive technologies can still invoke its default action directly; they
/// should not need to reproduce a mouse-specific click count.
struct GalleryItemButton<Label: View>: View {
    let action: () -> Void
    private let label: Label

    init(
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        label
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: action)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }
}
