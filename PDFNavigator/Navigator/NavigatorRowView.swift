import AppKit
import UniformTypeIdentifiers

/// One navigator row: icon, then name.
///
/// Subviews are declared as properties and composed with an `NSStackView`, so
/// the file reads in the order the row is drawn. Constraint-per-edge layout
/// describes a dependency graph instead, which is the main reason imperative
/// row code stops resembling the thing on screen.
final class NavigatorRowView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("NavigatorRow")

    /// `NSWorkspace.icon(forFile:)` asks LaunchServices about one specific path,
    /// and the old cell called it per row on every redraw. A PDF-only navigator
    /// draws exactly two icons, so both are resolved once by content type.
    private static let folderIcon = NSWorkspace.shared.icon(for: .folder)
    private static let pdfIcon = NSWorkspace.shared.icon(for: .pdf)

    private let icon: NSImageView = {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyDown
        return view
    }()

    private let title: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.lineBreakMode = .byTruncatingMiddle
        field.cell?.usesSingleLineMode = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }()

    private lazy var row: NSStackView = {
        let stack = NSStackView(views: [icon, title])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 2, bottom: 0, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier

        // `NSTableCellView` exposes these to the outline view for standard
        // source-list behaviour such as selection tinting.
        imageView = icon
        textField = title

        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func configure(with node: FileNode) {
        title.stringValue = node.name
        icon.image = node.isDirectory ? Self.folderIcon : Self.pdfIcon
    }
}
