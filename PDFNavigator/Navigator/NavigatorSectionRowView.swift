import AppKit

/// Section header row for the root workspace folder.
final class NavigatorSectionRowView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("NavigatorSectionRow")

    private let icon: NSImageView = {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyDown
        view.contentTintColor = .secondaryLabelColor
        return view
    }()

    private let title: NSTextField = {
        let field = NSTextField(labelWithString: "")
        field.font = .systemFont(ofSize: 12, weight: .bold)
        field.textColor = .labelColor
        field.lineBreakMode = .byTruncatingMiddle
        field.cell?.usesSingleLineMode = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }()

    private lazy var row: NSStackView = {
        let stack = NSStackView(views: [title])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        imageView = icon
        textField = title

        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func configure(with node: FileNode) {
        title.stringValue = node.name.uppercased()
        icon.image = NSImage(
            systemSymbolName: "folder.fill",
            accessibilityDescription: node.name
        )
    }
}
