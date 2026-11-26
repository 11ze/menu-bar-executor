import SwiftUI

/// 与 .ryugi/artifacts/html/menu-bar-executor/index.html 的表面、文字和分隔线角色对应。
enum InterfaceStyle {
    static let surface = color(light: 0xfdfdfe, dark: 0x292b30)
    static let chrome = color(light: 0xeff1f4, dark: 0x25272c)
    static let subtle = color(light: 0xf5f6f8, dark: 0x222429)
    static let material = color(light: 0xf6f8fb, dark: 0x25272c)
    static let line = color(light: 0xdce0e6, dark: 0x404249)
    static let text = color(light: 0x24262b, dark: 0xf0f1f4)
    static let muted = color(light: 0x626772, dark: 0xacb1ba)
    static let selectedText = color(light: 0x0068e8, dark: 0x83b9ff)
    static let selectedRowText = color(light: 0x005ecb, dark: 0x83b9ff)
    static let selection = color(light: 0xe4edfa, dark: 0x30455f)
    static let accent = Color(red: 0, green: 0.408, blue: 0.91)

    static let success = color(light: 0x267748, dark: 0x8cd9ac)
    static let failure = color(light: 0xbe3c36, dark: 0xff9d97)
    /// 浮动面板半透明外轮廓描边：浅色使用轻暗边、深色使用轻亮边，与桌面背景自然区分。
    static let panelBorder = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
            return NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.14)
        }
        return NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.12)
    })

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

struct ToolbarSearchField: View {
    let placeholder: String
    @Binding var text: String
    @State private var focused = false

    var body: some View {
        NativeSearchField(placeholder: placeholder, text: $text, focused: $focused)
            .frame(height: 34)
            .background(InterfaceStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(focused ? InterfaceStyle.selectedText : InterfaceStyle.line, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

private struct NativeSearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var focused: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> FocusReportingSearchField {
        let field = FocusReportingSearchField()
        field.cell = ToolbarSearchFieldCell(textCell: "")
        field.isEditable = true
        field.onFocusChange = { [weak coordinator = context.coordinator] focused in
            coordinator?.parent.focused = focused
        }
        field.placeholderString = placeholder
        field.setAccessibilityLabel(placeholder)
        field.font = .systemFont(ofSize: 12)
        // AppKit 的圆角搜索框会为字段编辑器保留放大镜和清空按钮的位置。
        field.isBezeled = true
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: FocusReportingSearchField, context: Context) {
        context.coordinator.parent = self
        field.syncTextPreservingMarkedText(text)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: NativeSearchField
        init(_ parent: NativeSearchField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }
    }
}

private final class ToolbarSearchFieldCell: NSSearchFieldCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        // 外框由 ToolbarSearchField 绘制，AppKit 负责图标和文本。
        drawInterior(withFrame: cellFrame, in: controlView)
    }
}

private final class FocusReportingSearchField: NSSearchField {
    var onFocusChange: ((Bool) -> Void)?

    override func selectText(_ sender: Any?) {
        super.selectText(sender)
        reportEditingFocusAsync(onFocusChange)
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        reportEditingFocusAsync(onFocusChange)
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        reportEditingFocusAsync(onFocusChange)
    }
}

extension NSTextField {
    /// 非中文组词态且文本不同时才回写，避免外部状态刷新打断 markedText。
    func syncTextPreservingMarkedText(_ text: String) {
        if stringValue != text, (currentEditor() as? NSTextView)?.hasMarkedText() != true {
            stringValue = text
        }
    }

    /// 在 AppKit 完成首响应者切换后的下一拍上报真实编辑焦点。
    func reportEditingFocusAsync(_ onFocusChange: ((Bool) -> Void)?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let focused = self.currentEditor().map { self.window?.firstResponder === $0 } ?? false
            onFocusChange?(focused)
        }
    }
}

struct CommandRowButtonStyle: ButtonStyle {
    /// 整行悬停或聚焦时显现边框；静止时只留文字（或按 invisibleWhenIdle 隐藏视觉但保留焦点链）。
    var revealed = true
    var invisibleWhenIdle = false

    func makeBody(configuration: Configuration) -> some View {
        RowLabel(
            label: configuration.label,
            pressed: configuration.isPressed,
            revealed: revealed,
            invisibleWhenIdle: invisibleWhenIdle
        )
    }

    private struct RowLabel: View {
        let label: ButtonStyleConfiguration.Label
        let pressed: Bool
        let revealed: Bool
        let invisibleWhenIdle: Bool
        @State private var hovered = false
        @Environment(\.isEnabled) private var enabled
        @Environment(\.isFocused) private var focused

        var body: some View {
            let highlighted = enabled && (hovered || pressed)
            let visible = enabled && (revealed || hovered || pressed || focused)
            let targetOpacity: Double = !enabled ? 0.4 : (invisibleWhenIdle && !visible ? 0 : 1)
            label.font(.system(size: 12))
                .foregroundColor(highlighted ? InterfaceStyle.selectedText : (visible ? InterfaceStyle.text : InterfaceStyle.muted))
                .padding(.horizontal, 8).frame(height: 26)
                .background(highlighted ? InterfaceStyle.selection : (visible ? InterfaceStyle.surface : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(focused ? InterfaceStyle.selectedText : (visible ? InterfaceStyle.line : Color.clear), lineWidth: focused ? 2 : 1))
                .cornerRadius(7).contentShape(Rectangle())
                .opacity(targetOpacity)
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
            label.font(.system(size: 12))
                .foregroundColor(hovered ? InterfaceStyle.selectedText : InterfaceStyle.text)
                .padding(.horizontal, 8).frame(height: 24)
                .background(hovered || pressed ? InterfaceStyle.selection : .clear)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(focused ? InterfaceStyle.selectedText : .clear, lineWidth: 2))
                .cornerRadius(6).contentShape(Rectangle())
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
                .background(prominent ? InterfaceStyle.accent : (hovered || pressed ? InterfaceStyle.selection : InterfaceStyle.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(focused ? InterfaceStyle.selectedText : (prominent ? Color.white.opacity(0.16) : InterfaceStyle.line), lineWidth: focused ? 2 : 1)
                )
                .cornerRadius(7)
                .shadow(color: prominent ? InterfaceStyle.accent.opacity(0.22) : .clear, radius: 2, x: 0, y: 1)
                .contentShape(Rectangle())
                .opacity(enabled ? 1 : 0.4)
                .onHover { hovered = enabled && $0 }
        }
    }
}

/// 清晰细边复选框样式：替代系统非激活态模糊灰块，保留完整点击热区、键盘焦点环、禁用态与开关语义。
struct InterfaceCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        CheckboxRow(configuration: configuration)
    }

    private struct CheckboxRow: View {
        let configuration: Configuration
        @State private var hovered = false
        @Environment(\.isEnabled) private var enabled
        @Environment(\.isFocused) private var focused

        var body: some View {
            Button {
                configuration.isOn.toggle()
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(configuration.isOn ? InterfaceStyle.accent : InterfaceStyle.surface)
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                configuration.isOn
                                    ? InterfaceStyle.accent
                                    : (enabled && hovered ? InterfaceStyle.selectedText : InterfaceStyle.line),
                                lineWidth: 1
                            )
                        if configuration.isOn {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 15, height: 15)
                    .overlay {
                        if focused {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(InterfaceStyle.selectedText, lineWidth: 2)
                                .padding(-2)
                        }
                    }
                    configuration.label
                }
                .frame(minHeight: 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(enabled ? 1 : 0.4)
            .onHover { hovered = enabled && $0 }
            .accessibilityValue(configuration.isOn ? "已开启" : "已关闭")
            .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
        }
    }
}

/// 表单单行 36pt 圆角框外观：供单行输入框与分组组合框共用。
struct InterfaceFieldChrome: ViewModifier {
    let focused: Bool

    func body(content: Content) -> some View {
        content
            .frame(height: 36)
            .background(InterfaceStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(focused ? InterfaceStyle.selectedText : InterfaceStyle.line, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

/// 表单单行输入框：整框留白均可点击聚焦，自带中文组词保护与一致的焦点边框。
struct InterfaceTextField: View {
    let placeholder: String
    @Binding var text: String
    var autoFocus = false
    @State private var focused = false

    var body: some View {
        NativeFormTextField(placeholder: placeholder, text: $text, autoFocus: autoFocus, focused: $focused)
            .modifier(InterfaceFieldChrome(focused: focused))
    }
}

struct NativeFormTextField: NSViewRepresentable {
    let placeholder: String
    var accessibilityLabel: String? = nil
    @Binding var text: String
    var autoFocus = false
    var trailingInset: CGFloat = 10
    @Binding var focused: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> PaddedTextFieldContainer {
        let container = PaddedTextFieldContainer(autoFocus: autoFocus, trailingInset: trailingInset)
        let field = container.field
        field.placeholderString = placeholder
        field.setAccessibilityLabel(accessibilityLabel ?? placeholder)
        field.stringValue = text
        field.font = .systemFont(ofSize: 13)
        field.textColor = NSColor(InterfaceStyle.text)
        field.delegate = context.coordinator
        field.onFocusChange = { [weak coordinator = context.coordinator] focused in
            coordinator?.parent.focused = focused
        }
        return container
    }

    func updateNSView(_ container: PaddedTextFieldContainer, context: Context) {
        context.coordinator.parent = self
        container.updateTrailingInset(trailingInset)
        let field = container.field
        if field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
        let targetLabel = accessibilityLabel ?? placeholder
        if field.accessibilityLabel() != targetLabel {
            field.setAccessibilityLabel(targetLabel)
        }
        field.syncTextPreservingMarkedText(text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeFormTextField
        init(_ parent: NativeFormTextField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

final class PaddedTextFieldContainer: NSView {
    let field = FocusReportingTextField()
    private let autoFocus: Bool
    private var didAutoFocus = false
    private var trailingConstraint: NSLayoutConstraint?

    init(autoFocus: Bool, trailingInset: CGFloat = 10) {
        self.autoFocus = autoFocus
        super.init(frame: .zero)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.lineBreakMode = .byTruncatingTail
        field.translatesAutoresizingMaskIntoConstraints = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(field)
        let trailing = field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -trailingInset)
        self.trailingConstraint = trailing
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            trailing,
            field.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func updateTrailingInset(_ inset: CGFloat) {
        guard trailingConstraint?.constant != -inset else { return }
        trailingConstraint?.constant = -inset
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 36)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard autoFocus, !didAutoFocus, window != nil else { return }
        didAutoFocus = true
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            if window.makeFirstResponder(self.field) {
                self.field.reportFocus()
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let window else {
            super.mouseDown(with: event)
            return
        }
        if let editor = field.currentEditor() as? NSTextView, window.firstResponder === editor {
            // 已在编辑态且处于中文组词期间，点击框内留白不得结束编辑或打断 markedText
            guard !editor.hasMarkedText() else { return }
            placeCaret(for: point, in: editor)
            return
        }
        if window.makeFirstResponder(field) {
            if let editor = field.currentEditor() as? NSTextView {
                placeCaret(for: point, in: editor)
            }
            field.reportFocus()
        }
    }

    private func placeCaret(for point: NSPoint, in editor: NSTextView) {
        let offset = point.x < field.frame.minX ? 0 : editor.string.utf16.count
        editor.selectedRange = NSRange(location: offset, length: 0)
    }
}

final class FocusReportingTextField: NSTextField {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { reportFocus() }
        return accepted
    }

    override func selectText(_ sender: Any?) {
        super.selectText(sender)
        reportFocus()
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        reportFocus()
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        reportFocus()
    }

    func reportFocus() {
        reportEditingFocusAsync(onFocusChange)
    }
}

/// 表单多行等宽命令编辑器：1px 焦点蓝边、关闭智能引号/破折号、中文组词保护、支持 ⌘↩ 快捷提交。
struct InterfaceTextEditor: View {
    @Binding var text: String
    var height: CGFloat = 86
    var accessibilityLabel: String = "命令内容"
    var onCommandReturn: (() -> Void)? = nil
    @State private var focused = false

    var body: some View {
        NativeCommandTextEditor(
            text: $text,
            accessibilityLabel: accessibilityLabel,
            focused: $focused,
            onCommandReturn: onCommandReturn
        )
        .frame(height: height)
        .background(InterfaceStyle.surface)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(focused ? InterfaceStyle.selectedText : InterfaceStyle.line, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

private struct NativeCommandTextEditor: NSViewRepresentable {
    @Binding var text: String
    let accessibilityLabel: String
    @Binding var focused: Bool
    let onCommandReturn: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> FocusForwardingScrollView {
        let scrollView = FocusForwardingScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = CommandEditorTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = NSColor(InterfaceStyle.text)
        textView.insertionPointColor = NSColor(InterfaceStyle.text)
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.setAccessibilityLabel(accessibilityLabel)
        textView.string = text
        textView.onFocusChange = { [weak coordinator = context.coordinator] isFocused in
            coordinator?.parent.focused = isFocused
        }
        textView.onCommandReturn = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onCommandReturn?()
        }

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: FocusForwardingScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? CommandEditorTextView else { return }
        if textView.string != text, !textView.hasMarkedText() {
            textView.string = text
        }
        if textView.accessibilityLabel() != accessibilityLabel {
            textView.setAccessibilityLabel(accessibilityLabel)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeCommandTextEditor
        init(_ parent: NativeCommandTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// 保证多行命令编辑框整框空白区域均可点击聚焦。
final class FocusForwardingScrollView: NSScrollView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        guard let textView = documentView as? NSTextView else { return }
        let width = max(0, contentSize.width)
        let minHeight = max(0, contentSize.height)
        if textView.minSize != NSSize(width: width, height: minHeight) {
            textView.minSize = NSSize(width: width, height: minHeight)
        }
        if textView.frame.height < minHeight || textView.frame.width != width {
            textView.setFrameSize(NSSize(width: width, height: max(textView.frame.height, minHeight)))
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        if hit === self || hit === contentView {
            return documentView ?? hit
        }
        return hit
    }

    override func mouseDown(with event: NSEvent) {
        if let textView = documentView as? NSTextView, window?.firstResponder !== textView {
            window?.makeFirstResponder(textView)
        }
        super.mouseDown(with: event)
    }
}

final class CommandEditorTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?
    var onCommandReturn: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChange?(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { onFocusChange?(false) }
        return accepted
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if !KeyDownMonitor.hasMarkedText(in: window?.firstResponder),
           !hasMarkedText(),
           event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.keyCode == KeyCode.returnKey {
            onCommandReturn?()
            return true
        }
        return super.performKeyEquivalent(with: event)
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
        let active = selection.wrappedValue == index
        return Button { selection.wrappedValue = index } label: {
            Text(title).font(.system(size: 12))
                .foregroundColor(active ? InterfaceStyle.text : InterfaceStyle.muted)
                .padding(.horizontal, 22).padding(.vertical, 4).frame(minHeight: 26)
                .background(active ? InterfaceStyle.surface : .clear)
                .cornerRadius(6)
                .shadow(color: active ? Color.black.opacity(0.08) : .clear, radius: 1.5, x: 0, y: 1)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(active ? .isSelected : [])
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
