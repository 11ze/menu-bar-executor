import Carbon

/// 输入法切换工具类
enum InputSourceHelper {
    // MARK: - 缓存
    private static var cachedSources: [(id: String, name: String)]?

    /// 获取所有可用的输入法列表（带缓存）
    static func availableInputSources(forceRefresh: Bool = false) -> [(id: String, name: String)] {
        if !forceRefresh, let cached = cachedSources {
            return cached
        }

        var sources: [(id: String, name: String)] = []

        guard let inputSources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return sources
        }

        for source in inputSources {
            // 只获取可选择的输入源（排除键盘布局等）
            guard let selectablePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable),
                  CFBooleanGetValue(unsafeBitCast(selectablePtr, to: CFBoolean.self)) else {
                continue
            }

            // 获取输入源 ID
            guard let sourceIDPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
                continue
            }
            let sourceID = unsafeBitCast(sourceIDPtr, to: CFString.self) as String

            // 获取本地化名称
            let localizedName: String
            if let localizedNamePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
                localizedName = unsafeBitCast(localizedNamePtr, to: CFString.self) as String
            } else {
                localizedName = sourceID
            }

            sources.append((id: sourceID, name: localizedName))
        }

        let result = sources.sorted { $0.name < $1.name }
        cachedSources = result
        return result
    }

    /// 获取当前输入法 ID
    static func currentInputSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return nil
        }

        guard let sourceIDPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return unsafeBitCast(sourceIDPtr, to: CFString.self) as String
    }

    /// 切换到指定输入法
    static func switchToInputSource(id: String) -> Bool {
        let sourceID = id as CFString
        let query: [String: Any] = [
            kTISPropertyInputSourceID as String: sourceID
        ]

        guard let matchingSources = TISCreateInputSourceList(query as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource],
              let targetSource = matchingSources.first else {
            return false
        }

        let result = TISSelectInputSource(targetSource)
        return result == noErr
    }
}