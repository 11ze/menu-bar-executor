import SwiftUI

/// 与 docs/design/prototype.html 的表面、文字和分隔线角色对应。
enum InterfaceStyle {
    static let surface = color(light: 0xfdfdfe, dark: 0x2c3037)
    static let chrome = color(light: 0xeff1f4, dark: 0x2f343d)
    static let subtle = color(light: 0xf5f6f8, dark: 0x272b32)
    static let material = color(light: 0xf6f8fb, dark: 0x2d333d)
    static let line = color(light: 0xdce0e6, dark: 0x434a55)
    static let text = color(light: 0x24262b, dark: 0xf0f1f4)
    static let muted = color(light: 0x626772, dark: 0xb1b7c2)
    static let selectedText = color(light: 0x0068e8, dark: 0x83b9ff)
    static let selection = color(light: 0xe1edfc, dark: 0x344e6e)

    private static func color(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

struct Keycap: View {
    let text: String

    var body: some View {
        Text(text).font(.system(size: 11)).foregroundColor(InterfaceStyle.muted)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(InterfaceStyle.surface)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(InterfaceStyle.line, lineWidth: 1))
            .cornerRadius(4).fixedSize()
    }
}

struct ToolbarSearchStyle: ViewModifier {
    let focused: Bool

    func body(content: Content) -> some View {
        content.padding(.horizontal, 13).frame(height: 34)
            .background(InterfaceStyle.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(focused ? Color.accentColor : InterfaceStyle.line, lineWidth: 1))
    }
}

struct CommandRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowLabel(label: configuration.label, pressed: configuration.isPressed)
    }

    private struct RowLabel: View {
        let label: ButtonStyleConfiguration.Label
        let pressed: Bool
        @State private var hovered = false
        @Environment(\.isEnabled) private var enabled
        @Environment(\.isFocused) private var focused

        var body: some View {
            let highlighted = enabled && (hovered || pressed)
            label.foregroundColor(highlighted ? InterfaceStyle.selectedText : InterfaceStyle.text)
                .padding(.horizontal, 8).frame(height: 26)
                .background(highlighted ? InterfaceStyle.selection : InterfaceStyle.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? Color.accentColor : InterfaceStyle.line, lineWidth: focused ? 2 : 1))
                .cornerRadius(8).contentShape(Rectangle())
                .opacity(enabled ? 1 : 0.4)
                .onHover { hovered = $0 }
        }
    }
}

struct CompactQuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        QuietLabel(label: configuration.label, pressed: configuration.isPressed)
    }

    private struct QuietLabel: View {
        let label: ButtonStyleConfiguration.Label
        let pressed: Bool
        @State private var hovered = false
        @Environment(\.isEnabled) private var enabled
        @Environment(\.isFocused) private var focused

        var body: some View {
            label.foregroundColor(InterfaceStyle.muted)
                .padding(.horizontal, 8).frame(minHeight: 26)
                .background(enabled && (hovered || pressed) ? InterfaceStyle.subtle : .clear)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? Color.accentColor : .clear, lineWidth: 2))
                .cornerRadius(8).contentShape(Rectangle())
                .opacity(enabled ? 1 : 0.4)
                .onHover { hovered = $0 }
        }
    }
}

struct PaletteFooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        FooterLabel(label: configuration.label, pressed: configuration.isPressed)
    }

    private struct FooterLabel: View {
        let label: ButtonStyleConfiguration.Label
        let pressed: Bool
        @State private var hovered = false
        @Environment(\.isFocused) private var focused

        var body: some View {
            label.font(.system(size: 11))
                .foregroundColor(hovered ? InterfaceStyle.selectedText : InterfaceStyle.text)
                .padding(.horizontal, 8).frame(height: 24)
                .background(hovered || pressed ? InterfaceStyle.selection : InterfaceStyle.surface)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(focused ? Color.accentColor : (hovered ? InterfaceStyle.selectedText.opacity(0.35) : InterfaceStyle.line), lineWidth: focused ? 2 : 1))
                .cornerRadius(6)
                .onHover { hovered = $0 }
        }
    }
}
