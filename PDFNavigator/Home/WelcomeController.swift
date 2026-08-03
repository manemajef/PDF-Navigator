import AppKit

final class WelcomeController: NSViewController {
    private let actions: WindowActions
    private let recentPDFsList = RecentPDFListView()

    init(actions: WindowActions) {
        self.actions = actions
        super.init(nibName: nil, bundle: nil)
        recentPDFsList.onOpenPDF = { [actions] url in
            actions.openPDF(url)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func loadView() {
        let container = NSView()

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
            title: "Open…",
            target: self,
            action: #selector(chooseLocation)
        )
        openButton.controlSize = .large
        openButton.bezelStyle = .rounded

        let stack = NSStackView(
            views: [iconView, titleLabel, subtitleLabel, openButton, recentPDFsList]
        )
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(20, after: subtitleLabel)
        stack.setCustomSpacing(20, after: openButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        let contentArea = container.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentArea.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentArea.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentArea.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentArea.trailingAnchor, constant: -32)
        ])
        let preferredWidth = recentPDFsList.widthAnchor.constraint(equalToConstant: 440)
        preferredWidth.priority = .defaultHigh
        preferredWidth.isActive = true

        view = container
    }

    func refresh() {
        loadViewIfNeeded()
        recentPDFsList.display(Array(RecentLocationsStore.shared.recentPDFs.prefix(5)))
    }

    @objc private func chooseLocation() {
        actions.chooseLocation()
    }
}
