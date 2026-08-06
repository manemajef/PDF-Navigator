import PDFKit
import SwiftUI

struct PDFOutlineView: View {
    let document: PDFDocument
    let onSelectOutline: (PDFOutline) -> Void

    var body: some View {
        let nodes = PDFOutlineNode.children(of: document.outlineRoot)

        if nodes.isEmpty {
            ContentUnavailableView(
                "No Table of Contents",
                systemImage: "list.bullet.indent"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                OutlineGroup(nodes, children: \.children) { node in
                    Button {
                        onSelectOutline(node.outline)
                    } label: {
                        Text(node.title)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }
}

#if DEBUG
#Preview("PDF Outline") {
    if let document = PDFDocument(
        url: DevelopmentConfiguration.demoOutlinePDFURL
    ) {
        PDFOutlineView(
            document: document,
            onSelectOutline: { _ in }
        )
        .frame(width: 300, height: 620)
    } else {
        ContentUnavailableView("PDF Unavailable", systemImage: "doc")
    }
}
#endif

private struct PDFOutlineNode: Identifiable {
    let outline: PDFOutline
    let children: [PDFOutlineNode]?

    var id: ObjectIdentifier { ObjectIdentifier(outline) }

    var title: String {
        let label = outline.label?.trimmingCharacters(in: .whitespacesAndNewlines)
        return label.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled"
    }

    init(outline: PDFOutline) {
        self.outline = outline
        let children = Self.children(of: outline)
        self.children = children.isEmpty ? nil : children
    }

    static func children(of parent: PDFOutline?) -> [PDFOutlineNode] {
        guard let parent else { return [] }

        var nodes: [PDFOutlineNode] = []
        for index in 0..<parent.numberOfChildren {
            if let child = parent.child(at: index) {
                nodes.append(PDFOutlineNode(outline: child))
            }
        }
        return nodes
    }
}
