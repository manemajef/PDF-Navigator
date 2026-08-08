import PDFKit
import Observation
import SwiftUI

enum PDFInspectorSection: String, CaseIterable, Identifiable {
    case thumbnails
    case outline
    case info

    var id: Self { self }

    var title: String {
        switch self {
        case .thumbnails:
            "Thumbnails"
        case .outline:
            "Table of Contents"
        case .info:
            "Info"
        }
    }

    var symbol: String {
        switch self {
        case .thumbnails:
            "square.grid.2x2"
        case .outline:
            "list.bullet.indent"
        case .info:
            "info.circle"
        }
    }
}

@Observable
final class PDFInspectorPresentationState {
    var section = PDFInspectorSection.thumbnails
}

/// SwiftUI content hosted by the native AppKit inspector split item.
struct PDFInspectorView: View {
    let session: PDFSession
    let readerState: PDFReaderPresentationState

    @Bindable var presentationState: PDFInspectorPresentationState

    let onSelectPage: (Int) -> Void
    let onSelectOutline: (PDFOutline) -> Void
    let onSectionChange: (PDFInspectorSection) -> Void

    private var inspectorPicker: some View {
        Picker("Inspector", selection: $presentationState.section) {
            ForEach(PDFInspectorSection.allCases) { section in
                Label(section.title, systemImage: section.symbol)
                    .labelStyle(.iconOnly)
                    .tag(section)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                
                if #available(macOS 27.0, *) {
                    inspectorPicker
                        .pickerStyle(.tabs)
                        .controlSize(.large)
                        .buttonSizing(.flexible)
                } else if #available(macOS 26.0, *) {
                    inspectorPicker
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                        .buttonSizing(.flexible)
                    
                }
                else {
                    inspectorPicker
                        .pickerStyle(.palette)
                        .controlSize(.large)
                        
                }
            }
            .labelsHidden()
            .help(presentationState.section.title)
            .padding(.top, 10)
            .padding(.horizontal, 10)
            .padding(.bottom, 5)
            
            .opacity(0.8)
           

//            Divider()

            if let document = session.document {
                switch presentationState.section {
                case .thumbnails:
                    PDFThumbnailsView(
                        document: document,
                        currentPageIndex: readerState.currentPageIndex,
                        onSelectPage: onSelectPage
                    )

                case .outline:
                    PDFOutlineView(
                        document: document,
                        onSelectOutline: onSelectOutline
                    )

                case .info:
                    PDFInfoView(
                        session: session,
                        readerState: readerState
                    )
                }
            } else {
                ContentUnavailableView(
                    "PDF Unavailable",
                    systemImage: "doc.badge.ellipsis"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: presentationState.section) { _, section in
            onSectionChange(section)
        }
    }
}

#if DEBUG
#Preview("PDF Inspector") {
    let readerState = PDFReaderPresentationState()

    readerState.update(
        currentPageIndex: 0,
        pageCount: 1,
        scaleFactor: 1,
        isZoomToFit: true
    )

    return PDFInspectorView(
        session: PDFSession(
            url: DevelopmentConfiguration.demoPDFURL
        ),
        readerState: readerState,
        presentationState: PDFInspectorPresentationState(),
        onSelectPage: { _ in },
        onSelectOutline: { _ in },
        onSectionChange: { _ in }
    )
    .frame(width: 240, height: 620)
}
#endif
