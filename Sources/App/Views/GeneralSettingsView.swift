import SwiftUI
import UniformTypeIdentifiers
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @ObservedObject private var settings = AppSettingsManager.shared
    @ObservedObject private var manager = CommandsManager.shared
    @State private var inputSources = InputSourceHelper.availableInputSources()
    @State private var importURL: URL?
    @State private var showingImportConfirmation = false

    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("呼出与输入") {
                        settingRow("全局快捷键", detail: "在任何应用中打开或关闭命令面板。") {
                            KeyboardShortcuts.Recorder(for: .commandPalette)
                            Button("清除") { KeyboardShortcuts.setShortcut(nil, for: .commandPalette) }
                        }
                        Divider()
                        settingRow("面板输入法", detail: "打开时切换，关闭后恢复原输入法。") {
                            Picker("面板输入法", selection: Binding(
                                get: { settings.settings.defaultInputSourceID ?? "" },
                                set: { settings.setDefaultInputSource($0.isEmpty ? nil : $0) }
                            )) {
                                Text("不切换").tag("")
                                if let currentID = settings.settings.defaultInputSourceID,
                                   !inputSources.contains(where: { $0.id == currentID }) {
                                    Text("当前配置已隐藏").tag(currentID).disabled(true)
                                }
                                ForEach(inputSources, id: \.id) { source in
                                    Text(source.name).tag(source.id)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 180)
                        }
                    }
                    section("启动、通知与更新") {
                        if LaunchAtLoginManager.shared.isSupported {
                            settingRow("登录时启动") {
                                Toggle("登录时启动", isOn: Binding(
                                    get: { settings.settings.launchAtLogin },
                                    set: { settings.setLaunchAtLogin($0) }
                                )).labelsHidden().toggleStyle(.switch)
                            }
                            Divider()
                        }
                        settingRow("系统通知", detail: "每条命令可单独设置完成通知，授权状态以系统设置为准。") {
                            Button("查看说明") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                            }
                        }
                        Divider()
                        settingRow("自动检查更新", detail: "启动时检查新版本，有更新时提醒。") {
                            Toggle("自动检查更新", isOn: Binding(
                                get: { settings.settings.autoCheckUpdates },
                                set: { settings.setAutoCheckUpdates($0) }
                            )).labelsHidden().toggleStyle(.switch)
                        }
                    }
                    section("配置文件") {
                        settingRow("备份与恢复", detail: "导入会替换命令、分组和通用设置。") {
                            Button("导出", action: exportConfig)
                            Button("导入…", action: showImportPanel)
                        }
                        Divider()
                        Text("~/.config/menu-bar-executor/settings.json")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(InterfaceStyle.muted)
                            .textSelection(.enabled)
                            .padding(.vertical, 12)
                    }
                }
                .padding(24)
            }
            .background(InterfaceStyle.subtle)
            Divider()
            HStack {
                Text("MenuBarExecutor")
                Spacer()
                Text("命令执行超时：30 秒")
            }.font(.caption).foregroundColor(InterfaceStyle.muted).padding(.horizontal, 20).padding(.vertical, 10).background(InterfaceStyle.chrome)
        }
        .onAppear { inputSources = InputSourceHelper.availableInputSources(forceRefresh: true) }
        .alert("确认导入", isPresented: $showingImportConfirmation) {
            Button("导入", role: .destructive) {
                if let url = importURL { manager.importSettings(from: url) }
                importURL = nil
            }
            Button("取消", role: .cancel) { importURL = nil }
        } message: {
            Text("导入将覆盖当前所有设置（包括命令和面板配置），确定要继续吗？")
        }
        .alert("操作失败", isPresented: Binding(
            get: { manager.lastError != nil },
            set: { if !$0 { manager.clearError() } }
        )) {
            Button("确定", role: .cancel) { manager.clearError() }
        } message: {
            Text(manager.lastError?.errorDescription ?? "未知错误")
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption).fontWeight(.semibold).foregroundColor(InterfaceStyle.muted)
            VStack(spacing: 0, content: content)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(InterfaceStyle.surface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(InterfaceStyle.line, lineWidth: 1))
                .cornerRadius(14)
        }
    }

    private func settingRow<Content: View>(_ title: String, detail: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                if let detail { Text(detail).font(.caption).foregroundColor(InterfaceStyle.muted).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 12)
            content()
        }.padding(.vertical, 14)
    }
    private func exportConfig() {
        let timestamp = Self.exportDateFormatter.string(from: Date())

        let panel = NSSavePanel()
        panel.title = "导出配置"
        panel.nameFieldStringValue = "settings-\(timestamp).json"
        panel.allowedContentTypes = [UTType.json]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            manager.exportSettings(to: url)
        }
    }

    private func showImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "导入配置"
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            importURL = url
            showingImportConfirmation = true
        }
    }
}
