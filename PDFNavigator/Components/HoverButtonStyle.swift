import SwiftUI

struct HoverButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 8
    var hoverColor: Color = Color.primary.opacity(0.06)
    var pressedColor: Color = Color.primary.opacity(0.12)

    func makeBody(configuration: Configuration) -> some View {
        HoverButtonBody(
            configuration: configuration,
            cornerRadius: cornerRadius,
            hoverColor: hoverColor,
            pressedColor: pressedColor
        )
    }

    private struct HoverButtonBody: View {
        let configuration: Configuration
        let cornerRadius: CGFloat
        let hoverColor: Color
        let pressedColor: Color

        @State private var isHovered = false

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            configuration.isPressed
                                ? pressedColor
                                : (isHovered ? hoverColor : Color.clear)
                        )
                )
                .onHover { hovering in
                    isHovered = hovering
                }
        }
    }
}

extension ButtonStyle where Self == HoverButtonStyle {
    static var hover: HoverButtonStyle {
        HoverButtonStyle()
    }

    static func hover(cornerRadius: CGFloat = 8) -> HoverButtonStyle {
        HoverButtonStyle(cornerRadius: cornerRadius)
    }
}

#Preview("Hover Button Style") {
    VStack(spacing: 12) {
        Button(action: {}) {
            HStack {
                Image(systemName: "folder.fill")
                Text("Hoverable Button")
            }
            .padding(10)
        }
        .buttonStyle(.hover)

        Button(action: {}) {
            Text("Custom Radius Button")
                .padding(10)
        }
        .buttonStyle(.hover(cornerRadius: 12))
    }
    .padding(20)
    .frame(width: 250)
}
