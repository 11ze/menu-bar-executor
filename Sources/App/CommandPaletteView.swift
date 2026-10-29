import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject private var coordinator: PaletteCoordinator
    @State private var editingCommand: Command?
    @FocusState private var isSearchFocused: Bool

    @MainActor
    init(coordinator: PaletteCoordinator? = nil) {
        self.coordinator = coordinator ?? .shared
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 17)).foregroundColor(InterfaceStyle.muted)
                    TextField("搜索命令…", text: $coordinator.searchText)
                        .textFieldStyle(.plain).font(.system(size: 17)).focused($isSearchFocused)
                        .onChange(of: coordinator.searchText) { _ in coordinator.selectFirstCommand() }
                    if !coordinator.searchText.isEmpty {
                        Button { coordinator.clearSearch() } label: {
                            Image(systemName: "xmark.circle.fill").frame(width: 24, height: 24).contentShape(Rectangle())
                        }
                            .buttonStyle(.plain).foregroundColor(InterfaceStyle.muted).accessibilityLabel("清空搜索")
                    } else { Keycap(text: "esc") }
                }.padding(.horizontal, 20).frame(height: 60)
                    .background(WindowDragArea()).background(InterfaceStyle.material)
                Divider()
                if coordinator.listModel.items.isEmpty {
                    VStack(spacing: 12) {
                        Text("›_").font(.system(size: 30, design: .monospaced)).foregroundColor(InterfaceStyle.muted).opacity(0.55)
                        Text(coordinator.searchText.isEmpty ? "还没有命令" : "没有匹配的命令").font(.system(size: 15, weight: .medium))
                        Text(coordinator.searchText.isEmpty ? "添加一条常用命令，随时呼出执行。" : "试试其他名称，或清空搜索。").font(.system(size: 12)).foregroundColor(InterfaceStyle.muted)
                        Button(coordinator.searchText.isEmpty ? "添加命令" : "清空搜索") {
                            if coordinator.searchText.isEmpty { editingCommand = Command(name: "", command: "") }
                            else { coordinator.clearSearch(); isSearchFocused = true }
                        }
                    }.buttonStyle(InterfaceButtonStyle()).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(coordinator.listModel.items.enumerated()), id: \.element.id) { index, item in
                                    switch item {
                                    case .groupHeader(let name):
                                        GroupHeaderRow(title: name)
                                    case .command(let command, let displayIndex):
                                        CommandPaletteRow(command: command, displayIndex: displayIndex,
                                                          isSelected: index == coordinator.listModel.selectedIndex,
                                                          searchText: coordinator.searchText,
                                                          autoExecuteState: coordinator.autoExecuteResults[command.id])
                                            .background(PalettePointerView { coordinator.selectOnHover(index) })
                                            .id(item.id)
                                    }
                                }
                            }.padding(.horizontal, 8).padding(.top, 9).padding(.bottom, 12)
                        }
                        .onChange(of: coordinator.scrollRequest) { target in
                            guard let target, coordinator.listModel.items.indices.contains(target) else { return }
                            isSearchFocused = true
                            proxy.scrollTo(coordinator.listModel.items[target].id)
                            coordinator.scrollRequest = nil
                        }
                    }
                }
                Divider()
                HStack(spacing: geometry.size.width < 400 ? 4 : (geometry.size.width < 540 ? 8 : 12)) {
                    HStack(spacing: 3) { Keycap(text: "↑"); Keycap(text: "↓"); Text("选择") }.fixedSize()
                    HStack(spacing: 3) { Keycap(text: "↵"); Text("执行") }.fixedSize()
                    Spacer(minLength: 4)
                    Button("执行历史") {
                        CommandPaletteWindowController.shared.hide()
                        HistoryWindowController.shared.showWindow()
                    }
                    Button("设置 ⌘,") {
                        CommandPaletteWindowController.shared.hide()
                        SettingsWindowController.shared.showWindow()
                    }
                }.font(.system(size: 10)).foregroundColor(InterfaceStyle.muted)
                    .buttonStyle(PaletteFooterButtonStyle())
                    .padding(.horizontal, 12).frame(height: 41)
                    .background(WindowDragArea()).background(InterfaceStyle.chrome)
            }
        }
        .foregroundColor(InterfaceStyle.text)
        .background(InterfaceStyle.surface)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .onReceive(coordinator.$searchText) { _ in
            DispatchQueue.main.async { isSearchFocused = true }
        }
        .onChange(of: isSearchFocused) { CommandPaletteWindowController.shared.isSearchFocused = $0 }
        .onAppear {
            coordinator.refreshCommands()
            DispatchQueue.main.asyncAfter(deadline: .now() + PaletteConfig.focusDelay) {
                CommandPaletteWindowController.shared.setSearchFocus = { isSearchFocused = $0 }
                isSearchFocused = true
            }
        }
        .sheet(item: $editingCommand, onDismiss: { isSearchFocused = true }) { command in
            CommandEditorView(command: command, onSave: { CommandsManager.shared.upsert($0) })
        }
    }
}

struct GroupHeaderRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundColor(InterfaceStyle.muted)
            Rectangle().fill(InterfaceStyle.line).frame(height: 1)
        }.padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 7).frame(height: 32)
    }
}

struct CommandPaletteRow: View {
    let command: Command
    let displayIndex: Int
    let isSelected: Bool
    let searchText: String
    let autoExecuteState: AutoExecuteState?
    @State private var showingResult = false
    @State private var copied = false
    @State private var resultButton: NSButton?
    @State private var resultHovered = false

    private var result: (text: String, marker: String, color: Color, canView: Bool)? {
        switch autoExecuteState {
        case .loading: return ("正在执行…", "●", InterfaceStyle.muted, false)
        case .success(let output): return (output.isEmpty ? "无输出" : output, "●", InterfaceStyle.success, !output.isEmpty)
        case .failure(let error): return (error, "●", InterfaceStyle.failure, !error.isEmpty)
        case .none: return nil
        }
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 8) {
                Button { PaletteCoordinator.shared.execute(command) } label: {
                    HighlightedText(text: command.name, search: searchText)
                        .font(.system(size: 13)).foregroundColor(isSelected ? InterfaceStyle.selectedText : InterfaceStyle.text)
                        .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 36).padding(.leading, 20)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).padding(.trailing, result == nil ? 0 : 4)
                if let result {
                    if result.canView {
                        NativeResultButton(text: result.text, color: result.color, name: command.name, hovered: resultHovered) { button in
                            resultButton = button
                            openResult()
                        }.frame(width: resultWidth(for: result.text, in: geometry.size.width)).frame(height: 36)
                            .onHover { resultHovered = $0 }
                            .popover(isPresented: $showingResult, arrowEdge: .bottom) {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(command.name).font(.system(size: 13, weight: .semibold))
                                        Spacer()
                                        Button("关闭") { showingResult = false }.keyboardShortcut(.cancelAction)
                                    }
                                    ScrollView {
                                        Text(result.text).font(.system(size: 12, design: .monospaced))
                                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                    }.frame(maxHeight: 180)
                                    Button(copied ? "已复制" : "复制结果") {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(result.text, forType: .string)
                                        copied = true
                                    }
                                }.padding(16).frame(width: 328)
                                .foregroundColor(InterfaceStyle.text).background(InterfaceStyle.surface)
                            }
                            .onChange(of: showingResult) { visible in
                                CommandPaletteWindowController.shared.resultPopoverIsPresented = visible
                                if !visible {
                                    if let button = resultButton {
                                        CommandPaletteWindowController.shared.focusResultButton(button)
                                    }
                                    CommandPaletteWindowController.shared.closeIfInactive()
                                }
                            }
                            .onDisappear {
                                if showingResult {
                                    CommandPaletteWindowController.shared.resultPopoverIsPresented = false
                                    CommandPaletteWindowController.shared.closeIfInactive()
                                }
                            }
                    } else { resultLabel(result).frame(width: resultWidth(for: result.text, in: geometry.size.width), alignment: .trailing) }
                }
                if displayIndex <= PaletteConfig.maxQuickSelectCount { Text("⌘\(displayIndex)").font(.system(size: 11)).foregroundColor(InterfaceStyle.muted) }
            }
            .padding(.trailing, 10).frame(height: 36)
            .background(isSelected ? InterfaceStyle.selection : .clear)
            .cornerRadius(7)
        }.frame(height: 36)
    }

    private func resultWidth(for text: String, in rowWidth: CGFloat) -> CGFloat {
        let titleWidth = ceil((command.name as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width)
        let shortcutWidth = displayIndex <= PaletteConfig.maxQuickSelectCount
            ? ceil(("⌘\(displayIndex)" as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width) + 8 : 0
        let available = max(17, rowWidth - 20 - titleWidth - 12 - shortcutWidth - 10)
        let inlineText = text.replacingOccurrences(of: "\n", with: " ")
        let textWidth = ceil((inlineText as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]).width)
        return min(textWidth + 17, available)
    }

    private func openResult() {
        copied = false
        CommandPaletteWindowController.shared.setSearchFocus?(false)
        CommandPaletteWindowController.shared.resultPopoverIsPresented = true
        showingResult = true
    }

    private func resultLabel(_ result: (text: String, marker: String, color: Color, canView: Bool)) -> some View {
        HStack(spacing: 6) {
            Text(result.marker).font(.system(size: 9)).foregroundColor(result.color)
            Text(result.text.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 11, design: .monospaced)).foregroundColor(InterfaceStyle.muted).lineLimit(1)

        }.help(result.text)
    }
}

/// 仅响应实际指针移动，布局或键盘滚动不会抢回选中项。
private struct PalettePointerView: NSViewRepresentable {
    let onMove: () -> Void

    func makeNSView(context: Context) -> PointerView { PointerView() }
    func updateNSView(_ view: PointerView, context: Context) { view.onMove = onMove }

    final class PointerView: NSView {
        var onMove: (() -> Void)?
        private var tracking: NSTrackingArea?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func updateTrackingAreas() {
            if let tracking { removeTrackingArea(tracking) }
            let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self)
            addTrackingArea(area)
            tracking = area
            super.updateTrackingAreas()
        }
        override func mouseEntered(with event: NSEvent) { selectIfMoved() }
        override func mouseMoved(with event: NSEvent) { selectIfMoved() }
        private func selectIfMoved() {
            let controller = CommandPaletteWindowController.shared
            let position = NSEvent.mouseLocation
            guard controller.lastPointerLocation != position else { return }
            controller.lastPointerLocation = position
            onMove?()
        }
    }
}

/// 原生按钮显式加入 Tab 焦点链，并让回车只打开结果。
private struct NativeResultButton: NSViewRepresentable {
    let text: String
    let color: Color
    let name: String
    let hovered: Bool
    let onActivate: (NSButton) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onActivate: onActivate) }
    func makeNSView(context: Context) -> PaletteResultButton {
        let button = PaletteResultButton()
        button.target = context.coordinator
        button.action = #selector(Coordinator.activate(_:))
        button.isBordered = false
        button.bezelStyle = .inline
        button.focusRingType = .exterior
        button.lineBreakMode = .byTruncatingTail
        button.imagePosition = .imageLeading
        button.alignment = .left
        button.cell?.usesSingleLineMode = true
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        DispatchQueue.main.async { [weak button] in
            if let button { CommandPaletteWindowController.shared.registerResultButton(button) }
        }
        return button
    }
    func updateNSView(_ button: PaletteResultButton, context: Context) {
        context.coordinator.onActivate = onActivate
        button.attributedTitle = NSAttributedString(string: text.replacingOccurrences(of: "\n", with: " "), attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor(hovered ? InterfaceStyle.selectedText : InterfaceStyle.muted)
        ])
        button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 6, weight: .regular))
        button.contentTintColor = NSColor(color)
        button.toolTip = "查看完整结果"
        button.setAccessibilityLabel("\(name)：查看完整结果")
    }

    final class Coordinator: NSObject {
        var onActivate: (NSButton) -> Void
        init(onActivate: @escaping (NSButton) -> Void) { self.onActivate = onActivate }
        @objc func activate(_ sender: NSButton) { onActivate(sender) }
    }
}

final class PaletteResultButton: NSButton {
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == KeyCode.returnKey { performClick(nil) }
        else { super.keyDown(with: event) }
    }
    override var focusRingMaskBounds: NSRect { bounds }
    override func drawFocusRingMask() { NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill() }
}
