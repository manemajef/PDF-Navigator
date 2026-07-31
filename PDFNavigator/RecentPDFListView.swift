import AppKit

final class RecentPDFListView: NSStackView {
    private var pdfs: [URL] = []

    var onOpenPDF: ((URL) -> Void)?

    init() {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func display(_ pdfs: [URL]) {
        self.pdfs = pdfs

        for view in arrangedSubviews {
            removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if pdfs.isEmpty {
            let label = NSTextField(labelWithString: "No recent PDFs.")
            label.textColor = .secondaryLabelColor
            addArrangedSubview(label)
            return
        }

        for (index, url) in pdfs.enumerated() {
            let button = NSButton(
                title: url.lastPathComponent,
                target: self,
                action: #selector(openPDF(_:))
            )
            button.tag = index
            button.bezelStyle = .inline
            button.alignment = .left
            button.image = NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
            button.imagePosition = .imageLeading
            addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        }
    }

    @objc private func openPDF(_ sender: NSButton) {
        guard pdfs.indices.contains(sender.tag) else { return }
        onOpenPDF?(pdfs[sender.tag])
    }
}
