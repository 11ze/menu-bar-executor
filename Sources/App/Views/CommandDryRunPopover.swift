import AppKit
import SwiftUI

/// 试跑结果浮层：复用面板结果浮层视觉语言，以 auto 模式运行（不落历史、不发通知），关闭时自动取消未完成进程。
struct CommandDryRunPopover: View {
    let command: Command
    let onClose: () -> Void

    @State private var state: AutoExecuteState = .loading
    @State private var copied = false
    @State private var activeHandle: ProcessHandle?

    private struct DisplayInfo {
        let label: String
        let color: Color
        let text: String
        let canCopy: Bool
    }

    private var resultInfo: DisplayInfo {
        switch state {
        case .loading:
            return DisplayInfo(label: "正在试跑…", color: InterfaceStyle.muted, text: "", canCopy: false)
        case .success(let output):
            let text = output.isEmpty ? "（无输出）" : output
            return DisplayInfo(label: "执行成功", color: InterfaceStyle.success, text: text, canCopy: !output.isEmpty)
        case .failure(let error):
            let text = error.isEmpty ? "执行失败" : error
            return DisplayInfo(label: "执行失败", color: InterfaceStyle.failure, text: text, canCopy: !error.isEmpty)
        }
    }

    var body: some View {
        let info = resultInfo
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if case .loading = state {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.65)
                        .frame(width: 10, height: 10)
                } else {
                    Circle().fill(info.color).frame(width: 6, height: 6)
                }
                Text(command.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "命令试跑" : command.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(info.label)
                    .font(.system(size: 11.5))
                    .foregroundColor(info.color)
                    .fixedSize()
                Spacer(minLength: 4)
                Button {
                    cancelActive()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(CompactQuietButtonStyle())
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("关闭试跑结果")
                .help("关闭")
            }

            if case .loading = state {
                HStack(spacing: 8) {
                    Text("命令正在执行，不会计入执行历史或发送系统通知。")
                        .font(.system(size: 12))
                        .foregroundColor(InterfaceStyle.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(InterfaceStyle.subtle)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(InterfaceStyle.line, lineWidth: 1))
                .cornerRadius(7)
            } else {
                ScrollView {
                    Text(info.text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(info.canCopy ? InterfaceStyle.text : InterfaceStyle.muted)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxHeight: 180)
                .background(InterfaceStyle.subtle)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(InterfaceStyle.line, lineWidth: 1))
                .cornerRadius(7)
            }

            HStack(spacing: 8) {
                if case .loading = state {
                    Button("停止") {
                        cancelActive()
                        state = .failure("已手动停止")
                    }
                    .buttonStyle(InterfaceButtonStyle(height: 28))
                } else {
                    Button(copied ? "已复制" : "复制结果") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(info.text, forType: .string)
                        copied = true
                    }
                    .buttonStyle(InterfaceButtonStyle(height: 28))
                    .disabled(!info.canCopy)

                    Button("重新试跑") {
                        startRun()
                    }
                    .buttonStyle(CompactQuietButtonStyle())
                }
                Spacer()
                Text("不计入历史")
                    .font(.system(size: 11))
                    .foregroundColor(InterfaceStyle.muted)
            }
        }
        .padding(16)
        .frame(width: 360)
        .font(.system(size: 12))
        .foregroundColor(InterfaceStyle.text)
        .background(InterfaceStyle.surface)
        .onAppear { startRun() }
        .onDisappear { cancelActive() }
    }

    private func startRun() {
        cancelActive()
        copied = false
        state = .loading
        activeHandle = CommandExecutor.shared.execute(command: command, mode: .auto) { result in
            activeHandle = nil
            switch result {
            case .success(let output):
                state = .success(output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            case .exitedAbnormally(let code, let output):
                let trimmed = output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                state = .failure(trimmed.isEmpty ? "退出码 \(code)" : "退出码 \(code)\n\(trimmed)")
            case .failed(let error):
                state = .failure(error.localizedDescription)
            }
        }
    }

    private func cancelActive() {
        activeHandle?.cancel()
        activeHandle = nil
    }
}
