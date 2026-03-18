import Foundation

enum AppError: LocalizedError {
    case configLoadFailed(Error)
    case configSaveFailed(Error)
    case configExportFailed(Error)
    case commandTimeout(seconds: Int)
    case commandExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .configLoadFailed(let error):
            return "配置加载失败: \(error.localizedDescription)"
        case .configSaveFailed(let error):
            return "配置保存失败: \(error.localizedDescription)"
        case .configExportFailed(let error):
            return "配置导出失败: \(error.localizedDescription)"
        case .commandTimeout(let seconds):
            return "命令执行超时（\(seconds)秒）"
        case .commandExecutionFailed(let message):
            return "命令执行失败: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .configLoadFailed:
            return "请检查配置文件格式是否正确"
        case .configSaveFailed:
            return "请检查磁盘空间和文件权限"
        case .configExportFailed:
            return "请检查目标路径是否可写"
        case .commandTimeout:
            return "请检查命令是否需要更长时间执行"
        case .commandExecutionFailed:
            return "请检查命令内容是否正确"
        }
    }
}
