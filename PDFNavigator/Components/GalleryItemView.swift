import SwiftUI

/// A Gallery item: one pointer click selects it, two open it.
///
/// Holds no state of its own — the grid decides what is selected, and what
/// opening means. Assistive technologies invoke opening through the default
/// action; they should not need to reproduce a mouse-specific click count.
struct GalleryItemView<Label: View>: View {
    /// Selection draws emphasized only while this window is the key one, which
    /// is what makes an inactive window's selection recede the way every other
    /// macOS list does.
    @Environment(\.controlActiveState) private var controlActiveState

    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    private let label: Label

    init(
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        onOpen: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onOpen = onOpen
        self.label = label()
    }

    var body: some View {
        styledLabel
            .background(selectionBackground)
            .contentShape(Rectangle())
            .onTapGesture(count: 2, perform: onOpen)
            // Recognised alongside the double click rather than after it. A
            // plain second `onTapGesture` would have to wait out the system
            // double-click interval before it could rule a double click out,
            // which is the delay between pressing and seeing the highlight.
            .simultaneousGesture(TapGesture().onEnded(onSelect))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(.default, onOpen)
    }

    private var isEmphasized: Bool {
        isSelected && controlActiveState == .key
    }

    /// `GalleryItemLabel` keeps asking for `.primary` and `.secondary`.
    /// Supplying both levels here is what lets its text invert over the
    /// emphasized fill without knowing anything about selection.
    @ViewBuilder
    private var styledLabel: some View {
        if isEmphasized {
            label.foregroundStyle(.white, .white.opacity(0.75))
        } else {
            label
        }
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    Color(
                        nsColor: isEmphasized
                            ? .selectedContentBackgroundColor
                            : .unemphasizedSelectedContentBackgroundColor
                    )
                )
        }
    }
}
