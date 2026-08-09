import SwiftUI
import UniformTypeIdentifiers

struct LibraryHeaderView: View {
    let folderName: String
    let folderPath: String
    let onOpenDifferent: () -> Void

    init(
        folderName: String,
        folderPath: String,
        onOpenDifferent: @escaping () -> Void = {}
    ) {
        self.folderName = folderName
        self.folderPath = folderPath
        self.onOpenDifferent = onOpenDifferent
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSWorkspace.shared.icon(for: .folder)
                  )
            .resizable()
            .scaledToFit()
            .frame(width: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(folderName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(folderPath)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .truncationMode(.middle)
                    .lineLimit(1)
            }

            Spacer()

            Button("Open Different…", action: onOpenDifferent)
                .controlSize(.large)
        }
    }
}

#Preview("Library Header View") {
    LibraryHeaderView(
        folderName: "Micro 3",
        folderPath: "~/University/Semester 4/Micro 3"
    )
    .padding(24)
    .frame(width: 600)
}
