import AppKit

final class WelcomeController: NSViewController {
    private let recentPDFsList = RecentPDFListView()

    var onChooseWorkspace: (() -> Void)?
    var onOpenRecentPDF: ((URL) -> Void)? {
        didSet { recentPDFsList.onOpenPDF = onOpenRecentPDF }
    }

    override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView(
            image: NSImage(
                systemSymbolName: "doc.richtext",
                accessibilityDescription: "PDF Navigator"
            ) ?? NSImage()
        )
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 54, weight: .regular)
        iconView.contentTintColor = .secondaryLabelColor

        let titleLabel = NSTextField(labelWithString: "PDF Navigator")
        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)

        let subtitleLabel = NSTextField(labelWithString: "Open a PDF or folder to begin.")
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor

        let openButton = NSButton(
            title: "Open New",
            target: self,
            action: #selector(chooseWorkspace)
        )
        openButton.controlSize = .large
        openButton.bezelStyle = .rounded

        let recentPDFsBox = NSBox()
        recentPDFsBox.title = "Recent PDFs"
        recentPDFsBox.contentView = recentPDFsList
        recentPDFsBox.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(
            views: [iconView, titleLabel, subtitleLabel, openButton, recentPDFsBox]
        )
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(20, after: subtitleLabel)
        stack.setCustomSpacing(20, after: openButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -32)
        ])
        let preferredWidth = recentPDFsBox.widthAnchor.constraint(equalToConstant: 440)
        preferredWidth.priority = .defaultHigh
        preferredWidth.isActive = true

        view = container
    }

    func refresh() {
        loadViewIfNeeded()
        recentPDFsList.display(Array(RecentLocationsStore.shared.recentPDFs.prefix(5)))
    }

    @objc private func chooseWorkspace() {
        onChooseWorkspace?()
    }
}
