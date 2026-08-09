import AppKit

/// The workspace-root row, drawn as a source-list group header.
///
/// A group row is not a file row: it is not selectable, it takes the outline
/// view's own header styling, and it shows no icon. Keeping it as its own type
/// means neither row has to carry a mode flag for the other's behaviour.
final class NavigatorSectionRowView: NSTextField {
    static let identifier = NSUserInterfaceItemIdentifier("NavigatorSectionRow")

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier

        isEditable = false
        isBordered = false
        isSelectable = false
        drawsBackground = false
        lineBreakMode = .byTruncatingMiddle
        cell?.usesSingleLineMode = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func configure(with node: FileNode) {
        stringValue = node.name
    }
}
