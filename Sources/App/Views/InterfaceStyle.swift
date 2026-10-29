import SwiftUI

/// 与 designs/menu-bar-executor/style.css 的表面、文字和分隔线角色对应。
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

    static let success = color(light: 0x267748, dark: 0x8cd9ac)
    static let failure = color(light: 0xbe3c36, dark: 0xff9d97)

    static func applyWindowChrome(to window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(material)
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(type)?.isHidden = true
        }
    }

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
        content.font(.system(size: 12)).padding(.horizontal, 12).frame(height: 34)
            .background(InterfaceStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? InterfaceStyle.selectedText : InterfaceStyle.line, lineWidth: 1))
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
            label.font(.system(size: 11)).foregroundColor(highlighted ? InterfaceStyle.selectedText : InterfaceStyle.text)
                .padding(.horizontal, 8).frame(height: 26)
                .background(highlighted ? InterfaceStyle.selection : InterfaceStyle.surface)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(focused ? InterfaceStyle.selectedText : InterfaceStyle.line, lineWidth: focused ? 2 : 1))
                .cornerRadius(7).contentShape(Rectangle())
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
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(focused ? InterfaceStyle.selectedText : .clear, lineWidth: 2))
                .cornerRadius(7).contentShape(Rectangle())
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

struct InterfaceButtonStyle: ButtonStyle {
    var prominent = false
    var height: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        LabelView(label: configuration.label, prominent: prominent, height: height, pressed: configuration.isPressed)
    }

    private struct LabelView: View {
        let label: ButtonStyleConfiguration.Label
        let prominent: Bool
        let height: CGFloat
        let pressed: Bool
        @State private var hovered = false
        @Environment(\.isEnabled) private var enabled
        @Environment(\.isFocused) private var focused

        var body: some View {
            label.padding(.horizontal, 11).padding(.vertical, 5).frame(minHeight: height)
                .foregroundColor(prominent ? .white : (hovered || pressed ? InterfaceStyle.selectedText : InterfaceStyle.text))
                .background(prominent ? Color(red: 0, green: 0.408, blue: 0.91) : (hovered || pressed ? InterfaceStyle.selection : InterfaceStyle.surface))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(focused ? InterfaceStyle.selectedText : (prominent ? .clear : InterfaceStyle.line), lineWidth: focused ? 2 : 1))
                .cornerRadius(7).contentShape(Rectangle())
                .opacity(enabled ? 1 : 0.4)
                .onHover { hovered = enabled && $0 }
        }
    }
}

struct InterfaceTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration.textFieldStyle(.plain).padding(.horizontal, 10).padding(.vertical, 8).frame(minHeight: 35)
            .background(InterfaceStyle.surface)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(InterfaceStyle.line, lineWidth: 1))
            .cornerRadius(7)
    }
}

struct WindowHeader: View {
    let title: String
    var selectedTab: Binding<Int>?

    var body: some View {
        HStack(spacing: 20) {
            WindowControls().frame(width: 47, height: 14)
            Text(title).font(.system(size: 13, weight: .semibold))
            Spacer()
            if let selectedTab {
                HStack(spacing: 2) {
                    tab("命令", index: 0, selection: selectedTab)
                    tab("通用", index: 1, selection: selectedTab)
                }.padding(3).background(InterfaceStyle.chrome).cornerRadius(8)
            }
        }.padding(.horizontal, 19).frame(height: 55)
            .background(InterfaceStyle.material)
            .background(WindowDragArea())
            .overlay(alignment: .bottom) { InterfaceStyle.line.frame(height: 1) }
    }

    private func tab(_ title: String, index: Int, selection: Binding<Int>) -> some View {
        Button { selection.wrappedValue = index } label: {
            Text(title).font(.system(size: 12))
                .foregroundColor(selection.wrappedValue == index ? InterfaceStyle.text : InterfaceStyle.muted)
                .padding(.horizontal, 22).padding(.vertical, 4).frame(minHeight: 26)
                .background(selection.wrappedValue == index ? InterfaceStyle.surface : .clear)
                .cornerRadius(6).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selection.wrappedValue == index ? .isSelected : [])
    }
}

/// 保留系统窗口按钮的辅助功能与关闭、最小化、缩放行为。
private struct WindowControls: NSViewRepresentable {
    func makeNSView(context: Context) -> ControlsView { ControlsView() }
    func updateNSView(_ view: ControlsView, context: Context) {}

    final class ControlsView: NSView {
        override init(frame: NSRect) {
            super.init(frame: frame)
            for (index, type) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
                guard let button = NSWindow.standardWindowButton(type, for: .titled) else { continue }
                button.frame = NSRect(x: index * 18, y: 1, width: 11, height: 11)
                button.setAccessibilityRole(.button)
                button.setAccessibilitySubrole([NSAccessibility.Subrole.closeButton, .minimizeButton, .zoomButton][index])
                button.setAccessibilityLabel(["关闭窗口", "最小化窗口", "缩放窗口"][index])
                button.target = self
                button.action = [#selector(closeWindow), #selector(minimizeWindow), #selector(zoomWindow)][index]
                addSubview(button)
            }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        @objc private func closeWindow() { window?.performClose(nil) }
        @objc private func minimizeWindow() { window?.miniaturize(nil) }
        @objc private func zoomWindow() { window?.zoom(nil) }
    }
}

/// 背景只接收空白区域的鼠标事件，控件仍处理自己的点击。
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}

/// SwiftUI 的 Settings 场景也使用同一窗口外观。
struct SettingsWindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> ChromeView { ChromeView() }
    func updateNSView(_ view: ChromeView, context: Context) {}

    final class ChromeView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { InterfaceStyle.applyWindowChrome(to: window) }
        }
    }
}
