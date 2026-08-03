import AppKit

final class WorkspaceHomeController: NSViewController {
    private let actions: WorkspaceActions
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let recentPDFsList = RecentPDFListView()

    init(actions: WorkspaceActions) {
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
                systemSymbolName: "folder",
                accessibilityDescription: "Workspace"
            ) ?? NSImage()
        )
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 54, weight: .regular)
        iconView.contentTintColor = .secondaryLabelColor

        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingMiddle
        subtitleLabel.maximumNumberOfLines = 2

        let openButton = NSButton(
            title: "Open Different Workspace",
            target: self,
            action: #selector(chooseWorkspace)
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

    func display(workspaceRootURL: URL) {
        loadViewIfNeeded()
        titleLabel.stringValue = workspaceRootURL.lastPathComponent.isEmpty
            ? "Workspace"
            : workspaceRootURL.lastPathComponent
        subtitleLabel.stringValue = workspaceRootURL.path

        let rootPath = workspaceRootURL.standardizedFileURL.path
        recentPDFsList.display(
            Array(
                RecentLocationsStore.shared.recentPDFs
                    .filter { $0.standardizedFileURL.path.hasPrefix(rootPath + "/") }
                    .prefix(5)
            )
        )
    }

    @objc private func chooseWorkspace() {
        actions.chooseWorkspace()
    }
}
