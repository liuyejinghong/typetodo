import Cocoa

let app = NSApplication.shared

#if DEBUG
// UI 验收快照模式：渲染完就退出，不进事件循环（详见 UIDebugSnapshot）
if UIDebugSnapshot.runIfRequested() { exit(0) }
#endif

let delegate = AppDelegate()
app.delegate = delegate
app.run()
