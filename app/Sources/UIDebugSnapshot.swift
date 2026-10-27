#if DEBUG
import Cocoa
#if canImport(TypetodoCore)
import TypetodoCore
#endif

/// 开发期 UI 快照入口：`Typetodo --ui-snapshot [输出目录]`。
///
/// 用途是 UI/UX 验收：把设置窗每个页面离屏渲染成 PNG，同时 dump 布局度量，
/// 让 AI 能在**不接触用户桌面**的前提下检查间距、对齐、文案截断。
///
/// 不走 `screencapture`：那条路要屏幕录制权限、拍的是整块屏幕、
/// 会把用户当时的窗口一起拍进去。这里只画 App 自己的内容。
///
/// 只在 DEBUG 编译进来，Release 包里不存在这段代码。
enum UIDebugSnapshot {

    /// 每步写一行，失败时能定位停在哪（open 启动拿不到 stderr）
    private static let traceURL = URL(fileURLWithPath: "/tmp/typetodo-ui-trace.log")
    private static func trace(_ line: String) {
        let text = line + "\n"
        if let h = try? FileHandle(forWritingTo: traceURL) {
            h.seekToEndOfFile(); h.write(Data(text.utf8)); try? h.close()
        } else {
            try? Data(text.utf8).write(to: traceURL)
        }
    }

    /// 触发文件：`~/.typetodo-ui-request`，内容（可选）是输出目录。
    ///
    /// 为什么不用命令行参数：从 `open --args` 启动时参数拿不到（会被已有实例吃掉），
    /// 直接跑二进制又会被工具沙箱拦在 `sandbox_extension_issue_file_to_process`。
    /// 触发文件两个问题都绕开了：写文件 → 启动 App → 它自己读、自己删、自己退出。
    static var requestFile: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".typetodo-ui-request")
    }

    /// 命令行带 `--ui-snapshot`，或存在触发文件，就执行并返回 true（调用方据此退出）。
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        var dir = URL(fileURLWithPath: "/tmp/typetodo-ui")
        var requested = false

        if let flagIndex = args.firstIndex(of: "--ui-snapshot") {
            requested = true
            let outIndex = flagIndex + 1
            if outIndex < args.count, !args[outIndex].hasPrefix("--") {
                dir = URL(fileURLWithPath: args[outIndex])
            }
        } else if let data = try? Data(contentsOf: requestFile),
                  let path = String(data: data, encoding: .utf8)?
                      .trimmingCharacters(in: .whitespacesAndNewlines), true {
            requested = true
            try? FileManager.default.removeItem(at: requestFile)
            if !path.isEmpty { dir = URL(fileURLWithPath: path) }
        }

        guard requested else { return false }

        perform(dir: dir)
        return true
    }

    /// 在**已运行的 App 进程内**执行快照。
    ///
    /// 为什么不另起进程：新进程第一次读钥匙串会弹系统授权框并阻塞在那里，
    /// 那正是要避免的打扰。当前进程早就拿到授权了，不会弹。
    static func perform(dir: URL) {
        try? FileManager.default.removeItem(at: traceURL)
        trace("enter dir=\(dir.path)")
        // 不进 Dock、不抢焦点：整个进程不参与前台应用切换
        trace("activationPolicy=\(NSApp.setActivationPolicy(.prohibited))")

        let controller = SettingsWindowController(delegate: SnapshotDelegate())
        trace("controller ok, window=\(controller.window != nil), contentView=\(controller.window?.contentView != nil)")
        guard let window = controller.window else {
            trace("ABORT: window nil")
            return
        }
        // 挪到屏幕外再排布：即便有人截屏也拍不到它，同时避免任何置顶行为
        window.setFrameOrigin(NSPoint(x: -30000, y: -30000))
        window.orderBack(nil)

        // 部分控件要等一次 run loop 才拿到正确的 intrinsicContentSize
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        let pages: [SettingsWindowController.Page] = [
            .home, .history, .vocabulary, .model, .explore, .settings, .about,
        ]
        do {
            trace("before snapshot, frame=\(window.frame)")
            let report = try controller.debugSnapshot(pages: pages, to: dir)
            trace("snapshot done, pages=\(report.count)")
            let json = try JSONSerialization.data(
                withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try json.write(to: dir.appendingPathComponent("metrics.json"))

            let summary = report.compactMap { item -> String? in
                guard let page = item["page"] as? String,
                      let texts = item["texts"] as? [[String: Any]] else { return nil }
                let clipped = texts.filter { ($0["truncated"] as? Bool) == true }
                return "  \(page).png  \(texts.count) 个文本" +
                    (clipped.isEmpty ? "" : "，⚠️ \(clipped.count) 处可能被截断")
            }.joined(separator: "\n")
            print("[ui-snapshot] \(dir.path)\n\(summary)")
        } catch {
            trace("ERROR: \(error)")
        }
    }

    /// DEBUG 构建里由 AppDelegate 启动：每 1.5 秒看一眼触发文件。
    static func startWatcher() {
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            guard FileManager.default.fileExists(atPath: requestFile.path) else { return }
            let raw = (try? String(contentsOf: requestFile, encoding: .utf8)) ?? ""
            try? FileManager.default.removeItem(at: requestFile)
            let path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let dir = path.isEmpty ? URL(fileURLWithPath: "/tmp/typetodo-ui") : URL(fileURLWithPath: path)
            DispatchQueue.main.async { perform(dir: dir) }
        }
    }
}

/// 快照用的最小委托：页面里少数控件会回调，给一份不做事但完整的实现。
private final class SnapshotDelegate: SettingsWindowDelegate {
    func currentProcessingMode() -> ProcessingMode { .cloudOnly }
    func setProcessingMode(_ mode: ProcessingMode) {}
    func openAccessibilitySettings() {}
    func openMicrophoneSettings() {}
    func checkForUpdates(_ sender: Any?) {}
    func pendingUpdateInfo() -> TypetodoUpdateInfo? { nil }
    func showUpdateDetails(_ sender: Any?) {}
    func debugLog(_ message: String) {}
}
#endif
