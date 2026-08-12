import SwiftUI

/// The selected appearance shared by every gallery item.
///
/// A modifier rather than a wrapper view: it adds a background and inverts the
/// label, so it contributes no structure of its own. It also carries no
/// behavior — clicks and focus belong to the shared gallery that owns the items.
private struct GallerySelectionModifier: ViewModifier {
    /// Selection draws emphasized only while this window is the key one, which
    /// is what makes an inactive window's selection recede the way every other
    /// macOS list does.
    @Environment(\.controlActiveState) private var controlActiveState

    let isSelected: Bool

    func body(content: Content) -> some View {
        styled(content)
            .background(background)
    }

    private var isEmphasized: Bool {
        isSelected && controlActiveState == .key
    }

    /// `GalleryItemLabel` keeps asking for `.primary` and `.secondary`.
    /// Supplying both levels here is what lets its text invert over the
    /// emphasized fill without knowing anything about selection.
    @ViewBuilder
    private func styled(_ content: Content) -> some View {
        if isEmphasized {
            content.foregroundStyle(.white, .white.opacity(0.75))
        } else {
            content
        }
    }

    @ViewBuilder
    private var background: some View {
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

extension View {
    /// Applies the gallery's selected appearance.
    func gallerySelection(_ isSelected: Bool) -> some View {
        modifier(GallerySelectionModifier(isSelected: isSelected))
    }
}
