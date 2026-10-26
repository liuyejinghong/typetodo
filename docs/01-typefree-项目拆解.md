# Typefree 项目拆解报告

> 版本 v0.1 ｜ 2026-10-26 ｜ 分析对象：`kdsz001/typefree` @ `119d657`（v3.0.14，2026-10-16）
> 用途：为 `typetodo` 二次开发做技术底座评估

---

## 一、结论先行

1. **这是一个"外挂式语音输入法"，不是输入法本体。** 它不做 IME，而是"全局手势 → 录音 → 云端识别 → LLM 润色 → 模拟 ⌘V 粘贴到任意 App 光标处"。技术难点全在系统权限与输入链路，不在 UI。
2. **架构底子很好，可分可拆。** 单 Xcode target + 一个 Swift Package 核心库（`VoicePolishCore`），**零第三方依赖**（只有 Sparkle 做自更新）。核心库与 UI 完全解耦——本机实测 `swift build` 32 秒通过，`swift test` **299 个用例全绿 / 14 秒**。这是二次开发最大的红利。
3. **UI 层是典型的"功能堆出来的"代码。** `SettingsWindowController.swift` **7,717 行**、`AppDelegate.swift` **3,490 行**，两个 god object 占 App 层 55%。二次开发若直接在原文件上改，一定会陷进去，必须先切分再动。
4. **三条硬约束，先看清再动手**：GPL-3.0（衍生作品必须开源）、`Typefree` 名称/图标/官网**不在**许可范围、试用与会员的**服务端不在仓库**（自编译版没有托管通道）。
5. **可复用度评估**：核心能力层（识别/润色/加密/管线）约 **80% 可直接复用**；交互与 UI 层建议**重写**——因为 typetodo 的投递目标可能不是"一段文本"，而是"一条待办"。

---

## 二、项目画像

| 项 | 值 |
|---|---|
| 仓库构成 | `mac/`（完整 macOS 源码）+ `docs/`（官网，GitHub Pages 静态站）+ `readme-assets/`（演示 GIF） |
| 语言 / 构建 | Swift 6，Xcode 项目（scheme `VoicePolish`）+ SwiftPM 子包 `VoicePolishCore` |
| 运行环境 | macOS 14.0+；**非沙盒**，Developer ID 签名（麦克风 + 辅助功能运行时授权） |
| 第三方依赖 | 仅 Sparkle 2.9.3（自更新）；其余全为系统框架 |
| 代码规模 | 100 个 `.swift` / **33,247 行**：App 层 20,366 ｜ Core 层 8,786 ｜ 测试 4,065 |
| 测试 | 38 个测试文件 / **299 个用例**，覆盖 Core 层 |
| 许可 | GPL-3.0；商标与官网内容不授权 |
| 产品形态 | 菜单栏 App（无 Dock 图标），全局热键 / 鼠标长按唤起 |

**技术栈分布**：AppKit（23 处 import）+ SwiftUI（仅回答面板 1 处）｜ AVAudioEngine 录音｜ URLSession 调云｜ CryptoKit AES-GCM｜ Security Keychain｜ ApplicationServices（AX）｜ NSPasteboard｜ SMAppService（开机自启）｜ WebKit（更新说明页）。

---

## 三、仓库目录结构

```
typefree/
├── mac/                              # ★ 唯一源码目录（GPL-3.0）
│   ├── VoicePolish.xcodeproj/         # 单 target：VoicePolish（app）
│   ├── Sources/                       # 应用层 20,366 行 / 19 文件（AppKit + 少量 SwiftUI）
│   │   ├── AppDelegate.swift          # 3,490  生命周期 / 录音编排 / 更新 UI / 菜单 / 引导
│   │   ├── SettingsWindowController.swift # 7,717 设置窗（7 页）+ 历史存储 + 自绘控件
│   │   ├── OverlayWindow.swift        # 1,664  录音胶囊 NSPanel + 声波
│   │   ├── AnswerPanel.swift          # 1,007  问 AI 回答面板（SwiftUI）
│   │   ├── SupportChatView.swift      # 1,284  反馈对话
│   │   ├── HotkeyManager.swift        #   769  全局热键 + Escape 拦截
│   │   ├── MouseHoldToTalkManager.swift #  676 鼠标长按说话
│   │   ├── HotWordsAutoLearner.swift  #   999  错词自动学习
│   │   ├── AudioRecorder.swift        #   608  录音（App 侧封装）
│   │   ├── TextInputLocator.swift     #   460  辅助功能焦点探测
│   │   ├── TextDelivery.swift         #   329  剪贴板投递
│   │   ├── MicrophoneManager.swift    #   319  麦克风权限/设备切换
│   │   ├── AppAppearance.swift        #   255  主题
│   │   ├── StatusBarController.swift  #   221  菜单栏
│   │   ├── AutoLearnScheduler.swift   #   218  学习调度
│   │   ├── WhatsNewGuideView.swift    #   150  更新说明（WebView）
│   │   ├── RhythmStripView.swift      #   126  音浪条
│   │   ├── LaunchAtLogin.swift        #    68  开机自启 / Dock 图标
│   │   └── main.swift                 #     6  NSApplication 启动
│   ├── VoicePolishCore/               # ★ 核心库 8,786 行 / 42 文件（可独立编译）
│   │   ├── Package.swift              # macOS 14 / iOS 16 双平台声明
│   │   ├── Sources/VoicePolishCore/
│   │   │   ├── VoicePolishPipeline.swift   #  463  识别→润色→收尾 主流程
│   │   │   ├── CloudASRTranscriber.swift   #  730  火山/百炼 4 档识别
│   │   │   ├── AIPolisher.swift            #1,143  润色 + 提示词 + 历史读写
│   │   │   ├── OmniTranscriber.swift       #  223  音频直喂 Qwen-Omni
│   │   │   ├── StreamingTranscriptionSession.swift #181 边录边发
│   │   │   ├── ChunkedASRCoordinator.swift #  183  长音频分片并发
│   │   │   ├── AudioRecorder/Chunker/WAV/M4A…         音频采集与编码
│   │   │   ├── HistoryCrypto.swift         #  169  AES-GCM 行级加密
│   │   │   ├── SecretStore.swift           #  106  Keychain 抽象
│   │   │   ├── VoicePolishConfig.swift     #  290  config.json + 敏感键分离
│   │   │   ├── LicenseManager.swift        #  451  授权码 / 会员（Ed25519 验签）
│   │   │   ├── TrialManager.swift          #  437  试用额度（证书 pinning）
│   │   │   ├── HostedRoute.swift           #   38  三通道路由
│   │   │   ├── PersonalVocabulary / VocabularyLearning / VocabularyMiner  词库与学习
│   │   │   ├── StyleProfiler.swift         #  317  场景化文风
│   │   │   ├── OutputLanguage(+Command)    #  225  语音口令："用英文"
│   │   │   └── AppGroupBridge / KeyboardSessionBootstrap  iOS 键盘预留
│   │   └── Tests/VoicePolishCoreTests/     # 38 文件 / 299 用例
│   ├── Resources/                     # 图标、entitlements（仅麦克风）
│   ├── build.sh                       # xcodebuild → dist/，支持 Developer ID 重签
│   ├── scripts/install_app.sh
│   └── local.build.env.example        # 试用服务器地址/证书指纹（私有，不入库）
├── docs/                              # 官网（25 个静态 HTML，三语）+ appcast.xml
└── readme-assets/                     # 演示 GIF（3.6MB，占仓库 26%）
```

---

## 四、分层架构

```
┌──────────────────────────────────────────────────────────────┐
│ 外部服务（全部为可替换的 HTTP 接口）                          │
│ 火山引擎 ASR(3 档)  百炼 Qwen3-ASR  润色 LLM(Qwen/GLM/豆包)   │
│ Qwen-Omni(音频直出)  自建托管 /trial /member   Sparkle appcast│
└───────────────▲──────────────────────────┬───────────────────┘
                │ HTTPS                    │ 自更新
┌───────────────┴──────────────────────────▼───────────────────┐
│ 应用层 mac/Sources（AppKit，20,366 行）                       │
│  手势入口 │ 浮窗胶囊 │ 设置·历史 │ 文本投递 │ 回答面板 │ 反馈 │
│  Hotkey / MouseHold / Overlay / Settings / TextDelivery       │
└───────────────▲──────────────────────────────────────────────┘
                │ 调用（单向依赖，Core 不认识 UI）
┌───────────────┴──────────────────────────────────────────────┐
│ 核心层 VoicePolishCore（8,786 行，可独立编译 + 299 测试）      │
│  Pipeline │ 识别 │ 润色 │ 词库·风格 │ 配置·加密·授权           │
└───────────────▲──────────────────────────────────────────────┘
                │ 使用
┌───────────────┴──────────────────────────────────────────────┐
│ 系统能力（macOS 授权后可用）                                  │
│  Accessibility(AX) │ NSPasteboard │ Keychain │ AVAudioEngine  │
└──────────────────────────────────────────────────────────────┘
```

**关键判断**：依赖是**严格单向**的——`Sources/` 有 11 处 `import VoicePolishCore`，Core 里**零处** import AppKit UI。这意味着"换壳"成本低：保留 Core，重写 Sources 完全可行。

---

## 五、主链路（一次说话发生了什么）

```
按住热键 / 鼠标长按
   ↓  HotkeyManager（NSEvent 全局监听 + CGEventTap 兜底）
AVAudioEngine 采集 16kHz 单声道浮点样本
   ↓  录音中可选：StreamingTranscriptionSession 每 ~6s 提交一段
CloudASRTranscriber（火山极速/标准/2.0 或百炼）→ 原始文本
   ↓  失败：临时错误原地重试一次；仍失败 → 音频存历史标记"可重试"
AIPolisher（口语去冗余 + 标点分段 + 术语纠正 + 词库热词）
   ↓  ≤10 字短句直接直出，不调模型（省时省钱）
TextDelivery：写剪贴板（打 transient 标记）→ 合成 ⌘V → 0.6s 后还原剪贴板
   ↓
polish_log.jsonl（AES-GCM 行级加密）+ audio/<id>.m4a
```

**四个反直觉的设计**（值得直接抄）：

| 设计 | 为什么这么做 |
|---|---|
| 短句（≤10 字）不调模型 | 润色收益低、延迟高；实测直接出字更"跟手" |
| 剪贴板打 `org.nspasteboard.TransientType` | 否则 Maccy / Raycast 会把每句话都记进剪贴板历史 |
| 粘贴后 0.6s 再还原剪贴板 | Electron / 网页 / 远程桌面读剪贴板慢，早还原会把用户原内容粘进去 |
| 识别失败也存历史 | 用户白说一句话的成本远高于一条记录的存储成本 |

---

## 六、模块拆解与可复用性

复用分级：**A** 直接复用 ｜ **B** 改配置/小改 ｜ **C** 建议重写

### 6.1 交互与手势（App 层）

| 模块 | 文件 | 行数 | 职责 | 复用 |
|---|---|---|---|---|
| 全局热键 | `HotkeyManager.swift` | 769 | 组合键监听、自定义快捷键、录制时拦截 Esc | B（依赖 Core 的配置键） |
| 鼠标长按 | `MouseHoldToTalkManager.swift` | 676 | 长按说话、下拖锁定、拖远取消、合成事件 | B |
| 悬浮胶囊 | `OverlayWindow.swift` | 1,664 | 非激活 NSPanel、声波、多屏定位、学习提示 | C（视觉要换） |
| 回答面板 | `AnswerPanel.swift` | 1,007 | 问 AI 的流式回答、追问、图钉 | C |
| 菜单栏 | `StatusBarController.swift` | 221 | 状态图标与菜单 | B |

### 6.2 音频与识别（Core 层）

| 模块 | 文件 | 行数 | 职责 | 复用 |
|---|---|---|---|---|
| 录音 | `AudioRecorder.swift` / `SimpleAudioRecorder.swift` | 452 | AVAudioEngine + 电平回调 + 状态机 | **A** |
| 云端识别 | `CloudASRTranscriber.swift` | 730 | 火山 3 档（同步/异步 submit+query）+ 百炼，4 种错误分类 | **A**（换 Key 即用） |
| 全模态直出 | `OmniTranscriber.swift` | 223 | WAV 直喂 Qwen-Omni，一步出稿 | B |
| 边录边发 | `StreamingTranscriptionSession.swift` | 181 | 停顿检测、6s 一段、串行提交、尾巴合并 | **A** |
| 长音频分片 | `ChunkedASRCoordinator.swift` + `AudioChunker.swift` | 397 | 并发限流、顺序拼接、"无语音"并段恢复 | **A** |
| 无语音恢复 | 同上 | — | 火山误判 20000003 时并回相邻段重识别 | **A** |

### 6.3 文本产出（Core 层）

| 模块 | 文件 | 行数 | 职责 | 复用 |
|---|---|---|---|---|
| 处理管线 | `VoicePolishPipeline.swift` | 463 | 状态回调、取消令牌、超时丢弃、失败保留 | **A** |
| AI 润色 | `AIPolisher.swift` | 1,143 | 多 provider、提示词、模型路由、历史写盘 | **B**（提示词必改） |
| 模型路由 | `PolishModelRouter.swift` | 67 | 自动按质量/速度选模型 | A |
| 术语纠正 | `AIPolisher` 内 `TermCorrection` | — | 用户自定义"错词→正确词" | **A** |
| 输出语言 | `OutputLanguage(+Command).swift` | 225 | 规则识别"用英文"口令，非模型猜测 | A |
| 文风档案 | `StyleProfiler.swift` | 317 | 按场景（聊天/邮件/代码）调风格 | B |
| 投递 | `TextDelivery.swift` + `TextInputLocator.swift` | 789 | 焦点判定、粘贴、剪贴板还原 | **C**（typetodo 目标不同） |

### 6.4 数据与隐私（Core 层）

| 模块 | 文件 | 行数 | 职责 | 复用 |
|---|---|---|---|---|
| 配置 | `VoicePolishConfig.swift` | 290 | `~/.config/<app>/config.json`，写失败回退 Application Support | **A** |
| 凭证 | `SecretStore.swift` | 106 | Keychain 协议化，区分"没有"与"读不到" | **A** |
| 历史加密 | `HistoryCrypto.swift` | 169 | AES-GCM 逐行加密，前缀 `vpenc1:`，密钥丢失降级广播 | **A** |
| 音频仓库 | `AudioClipStore.swift` | 211 | m4a 落盘、过期清理、孤儿回收 | A |
| 统计 | `InputStats.swift` | 208 | 每日字数/时长 | B |

### 6.5 词库与学习

| 模块 | 文件 | 行数 | 职责 | 复用 |
|---|---|---|---|---|
| 个人词库 | `PersonalVocabulary.swift` | 159 | 热词注入识别（火山 hotwords 格式） | **A** |
| 学习 | `VocabularyLearning.swift` / `VocabularyMiner.swift` | 446 | 从历史挖高频词、改错一次自动记住 | **A** |
| 自动学习 | `HotWordsAutoLearner.swift`（App） | 999 | 监听光标处文本变化做纠错学习 | C（强依赖 AX） |

### 6.6 商业化（可整块删除）

| 模块 | 文件 | 行数 | 复用 |
|---|---|---|---|
| 授权码 / 会员 | `LicenseManager.swift` | 451 | 自建则重写（含 Ed25519 验签、设备绑定） |
| 试用额度 | `TrialManager.swift` | 437 | 依赖私有服务端，**开源版默认不可用** |
| 通道路由 | `HostedRoute.swift` | 38 | 逻辑值得保留：会员 > 自带 Key > 试用 |

### 6.7 UI 与运营

| 模块 | 文件 | 行数 | 说明 |
|---|---|---|---|
| 设置窗 | `SettingsWindowController.swift` | **7,717** | 7 页：首页/历史/反馈/词库/模型/探索/关于；**内含 `PolishHistoryStore` 与全部自绘控件** |
| 反馈 | `SupportChatView.swift` + `SupportChat.swift` | 1,726 | 站内对话、截图附件 |
| 更新 | `AppDelegate` 内 Sparkle 委托 | ~1,200 | **自定义更新弹窗，占 AppDelegate 三分之一** |
| 引导 | `OnboardingWindowController` / `WhatsNewGuideView` | ~300 | 首启与更新说明 |

---

## 七、八个关键机制（二次开发的"知识点"）

| # | 机制 | 实现要点 | 坑 |
|---|---|---|---|
| 1 | 全局热键 | `NSEvent.addGlobalMonitor` 监听 flagsChanged/keyDown，另有 `CGEventTap` 兜底；录制快捷键时用 `EscapeInterceptor` 抢 Esc | 两者不能同时启用，否则按键被吞 |
| 2 | 鼠标长按说话 | 全局监听 `leftMouseDown/Dragged/Up`，用 `CGEvent.post` 合成松开事件 | 必须豁免自己的窗口，否则点浮窗也会触发 |
| 3 | 焦点探测 | AX API 从 `AXFocusedUIElement` 向上找可编辑祖先；微信等自绘 App 读不到结构 → 返回 `unknown` 按"可以粘"处理 | 不能把"读不到"当"不能输入"，否则微信里永远不粘贴 |
| 4 | 文本投递 | 写剪贴板 → 合成 ⌘V → 0.6s 后按 `changeCount` 判断是否还原 | 见第五节四条设计 |
| 5 | 识别容错 | 错误分 4 类：网络（不换版本）、繁忙（原地重试一次）、业务失败、无语音（当空结果） | 不要"偷偷换模型"，用户选了哪个就用哪个 |
| 6 | 三通道路由 | 会员优先 > 自带 Key > 试用；`hostedAvailable` 由构建期注入的服务器地址决定 | 开源自编译版必须优雅降级为"只用自己的 Key" |
| 7 | 历史加密 | 密钥存 Keychain，逐行 `AES.GCM.seal`，前缀标记；读不到密钥时**不**生成新密钥（否则旧数据永久乱码） | 这是最容易写错的一处 |
| 8 | 自更新 | Sparkle 2 + `appcast.xml` + Ed25519 公钥；自绘更新 UI 接管全部回调 | 换 App 必须换 feed URL 与公钥 |

---

## 八、二次开发风险清单

| 等级 | 风险 | 影响 | 对策 |
|---|---|---|---|
| 🔴 高 | **GPL-3.0 传染** | 基于它发布的 typetodo 必须开源（含网络分发） | 要么接受 GPL 开源，要么 **clean-room 重写**（只借鉴思路不复制代码） |
| 🔴 高 | **商标/图标不授权** | 不能叫 Typefree、不能用其图标与官网文案 | 全新命名、全新图标、全部文案重写（typetodo 已满足） |
| 🔴 高 | **两个 god object** | 改设置页要读 7,717 行；改流程要读 3,490 行 | 先做"拆文件不改行为"的重构，再动功能 |
| 🟠 中 | **服务端缺失** | 试用/会员/托管通道不可用；`api.typefree.app` 拿不到 | 一期只做"自带 Key"，托管服务自建或不做 |
| 🟠 中 | **投递语义不匹配** | 原设计是"粘贴一段文字"，typetodo 若要"生成待办"需新链路 | 保留 Pipeline，替换"收尾"环节为结构化解析 |
| 🟠 中 | **无 iOS / Windows 源码** | 只有 macOS；Core 声明支持 iOS 但 UI 不在仓库 | 跨端需自建 UI，Core 可复用 |
| 🟠 中 | **系统权限门槛** | 辅助功能 + 麦克风；未签名/未公证会被 Gatekeeper 拦 | 需 Apple Developer 账号做 Developer ID 签名与公证 |
| 🟡 低 | **构建链要求** | 需完整 Xcode（CLT 编不过测试：`no such module 'XCTest'`） | 配 `xcode-select -s /Applications/Xcode.app` |
| 🟡 低 | **隐私合规** | 音频上云、转写文本落盘；国内需符合个保法告知同意 | 首启明示、可本地关闭、保留时长可配 |

### 本机实测记录（可行性验证）

| 项 | 结果 |
|---|---|
| 环境 | macOS 27.0.1 / Xcode 27.0 / Swift 6.2.4 |
| `swift build`（Core） | ✅ 32 秒通过，无警告阻塞 |
| `swift test`（Core） | ✅ **299 用例 / 0 失败 / 14 秒** |
| `xcodebuild`（App） | ⏸ 未跑：`xcode-select` 指向 CommandLineTools，需切到 Xcode.app（要 sudo，留给你执行） |
| 仓库体积 | 源码 2.0M（含 GIF 与官网共 32M） |

---

## 九、typetodo 结构建议

### 9.1 改造策略：**留核心、换外壳、加语义**

```
typefree（上游）                typetodo（我们）
─────────────────────────────────────────────────────────
VoicePolishCore  ──复用 80%──▶  TypetodoCore（重命名 + 裁剪商业化）
  ├ 识别/润色/加密/配置         ├ 保留
  ├ License/Trial/HostedRoute   └ 删除
  └ Pipeline                    └ 收尾环节改为「结构化解析」
Sources（AppKit UI） ──重写──▶  TypetodoApp
  ├ 设置窗 7,717 行             ├ 拆为 7 个独立页面 + 一个 Store
  └ 文本投递                    └ 待办投递（清单/提醒/标签）
```

### 9.2 建议目录

```
typetodo/
├── app/                        # macOS 应用（AppKit + SwiftUI 混合）
│   ├── Typetodo.xcodeproj/
│   └── Sources/
│       ├── App/                # 生命周期、DI 容器（≤300 行/文件）
│       ├── Features/           # Capture / Inbox / Settings / History
│       │   ├── Capture/        # 手势、录音态、浮窗
│       │   └── Inbox/          # 待办列表（typetodo 的差异点）
│       ├── Services/           # 投递、通知、快捷键、权限
│       └── UI/                 # 设计系统与复用控件
├── core/                       # TypetodoCore（SwiftPM，可测可移植）
│   ├── Sources/
│   │   ├── Audio/  ASR/  Polish/  Parse/  Storage/  Config/
│   └── Tests/
├── docs/                       # 本文档与后续 PRD
└── research/typefree/          # 上游源码（只读参考，不参与构建）
```

### 9.3 里程碑

| 阶段 | 目标 | 验收 |
|---|---|---|
| M0 跑通 | 上游能本机编译并装上，用自己的火山 Key 说出字 | 一段 10 秒语音 → 正确粘贴到备忘录 |
| M1 换壳 | 改名、换图标、删商业化、设置窗拆分为 7 页 | 全功能可用，无 Typefree 痕迹 |
| M2 加语义 | 语音 → 结构化待办（标题/时间/优先级），落到本地清单 | 说"明天下午三点提醒我交周报"生成一条待办 |
| M3 打磨 | 通知、清单视图、导出、隐私开关 | 自用一周不别扭 |

---

## 十、待你拍板的三件事

1. **typetodo 到底是什么？**
   - A：更顺手的语音输入工具（同质竞争，最快）
   - B：语音 → 待办/清单（有差异化，需新增解析层与清单 UI）
   - C：语音 → 结构化记录（会议纪要/灵感，解析难度更高）
2. **平台范围**：只 macOS？还是 macOS + iOS（Core 已声明支持 iOS 16，但键盘扩展需自建）？
3. **开源策略**：
   - A：跟随 GPL-3.0 开源（合规最省事，可继续用上游代码）
   - B：clean-room 重写（可闭源，但要重写全部 Core，工期 +3~4 周）

> 本方案为产品设计参考，具体实施请结合公司合规与法务要求确认。
