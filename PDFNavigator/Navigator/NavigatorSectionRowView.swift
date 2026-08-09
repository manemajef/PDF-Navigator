import AppKit

/// The workspace-root row, drawn as a source-list group header.
///
/// Not selectable, no icon, and styled by the outline view itself.
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
