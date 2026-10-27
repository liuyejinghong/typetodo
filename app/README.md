# Typetodo（macOS）

**基于语音的待办 App：按住快捷键说话，松手后这句话已经变成结构化待办；听写能力沿用原版不变。**

> Typetodo 是 [Typefree](https://github.com/kdsz001/typefree) 3.0.14 的衍生作品（GPL-3.0）。
> 「Typefree」名称、图标与官网内容不属于开源许可范围，本项目已全部替换为自有品牌。

## 当前状态

一期目标：**自带 Key、纯本地跑通**，不依赖任何自建服务端。

| 能力 | 状态 |
|---|---|
| 语音听写（原版能力，按住说话→AI 整理→投递到光标处） | ✅ 可用 |
| 空白处长按问 AI、语音翻译口令、词库学习、本地加密历史 | ✅ 可用（原版能力，行为不变） |
| 语音创建待办（⌘+左键长按 → LLM 结构化 → 本地 SQLite） | 🚧 开发中 |
| 本地提醒（UNUserNotificationCenter） | 🚧 开发中 |
| 试用 / 会员服务端 | ❌ 一期不做，只预留接口 |

产品文档在仓库根目录 `docs/`，其中 `05-PRD` 是产品需求、`06-开发方案` 是实施计划。

## 从源码构建

要求：macOS 14.0+、Xcode 26.3+（Swift 6）。

```bash
cd app
./scripts/fetch-sparkle.sh        # 首次：拉取 Sparkle 到 vendor/（约 22 MB，不入库）
./build.sh                        # 产物在 dist/Typetodo Install.app
bash scripts/install_app.sh       # 安装到 /Applications
```

也可以直接用 Xcode 打开 `Typetodo.xcodeproj`，scheme `Typetodo`。签名换成你自己的 Team 即可。

### 本地开发签名（重要）

用 ad-hoc 签名（`CODE_SIGN_IDENTITY="-"`）时，辅助功能/麦克风这类授权**每次重编都会丢**：
TCC 把授权绑在签名的 designated requirement 上，ad-hoc 的 requirement 是 cdhash，随二进制变化。

所以本地装到 `/Applications` 测试时用 Apple Development 证书重签：

```bash
../tools/xcodebuild.sh -project Typetodo.xcodeproj -scheme Typetodo \
  -configuration Debug -derivedDataPath /tmp/TypetodoDerived \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual CODE_SIGNING_REQUIRED=YES \
  OTHER_SWIFT_FLAGS='-Xfrontend -disable-sandbox' build

bash scripts/sign-dev.sh /tmp/TypetodoDerived/Build/Products/Debug/Typetodo.app
ditto /tmp/TypetodoDerived/Build/Products/Debug/Typetodo.app /Applications/Typetodo.app
```

`sign-dev.sh` 按由内到外的顺序签（Sparkle XPC → 辅助工具 → 框架 → Debug dylib → app），
且**不加 `--options runtime`**：硬化运行时的库校验要求主二进制与 `Typetodo.debug.dylib`
的 Team ID 一致，只签外层会导致启动即崩。

**自己编译的版本只能用自带 Key**（服务端地址不在仓库里，见 `local.build.env.example`）。装好后到「设置 → 模型」填入自己的 API Key。

### 在沙箱/CI 里构建

Xcode 的 SwiftPM 会在内层再套一层 Seatbelt，嵌套沙箱会被内核拒绝（`sandbox_apply: Operation not permitted`）。
外层已有沙箱时，用仓库根的包装脚本：

```bash
../tools/xcodebuild.sh -project Typetodo.xcodeproj -scheme Typetodo -configuration Debug build
```

### 核心库测试

```bash
cd app/TypetodoCore
swift test --disable-sandbox -Xswiftc -Xfrontend -Xswiftc -disable-sandbox
```

`-disable-sandbox` 是必需的：Swift 宏插件（`swift-plugin-server`）自带一层沙箱，在受限环境里会启动失败并报
`external macro implementation type ... produced malformed response`。

基线：**293 用例 / 0 失败**。

### 结构不变量检查

改名、拆页时最容易静默踩的坑是 selector 变孤儿。每次搬动 UI 后跑（在仓库根目录）：

```bash
python3 tools/check_app_invariants.py app/Sources
```

基线：**98 个本地 selector / 0 孤儿 / 7 个页面分支**。

## 目录

- `Sources/` — macOS 状态栏 App（AppKit + 少量 SwiftUI）
- `TypetodoCore/` — 核心库（录音、云端识别、AI 润色、词库、历史加密），Swift Package
- `Resources/` — 图标、entitlements、新功能演示页
- `Typetodo.xcodeproj/` — 单 target 工程
- `build.sh` / `scripts/` — 本地构建、安装、依赖拉取

不在这里的：iOS 版、Windows 版、试用服务器、激活服务、评测工具。

## 隐私

- API Key 只保存在本机钥匙串，绝不上传
- 自带 Key 时，音频直接发给你选的模型厂商，不经过任何中转
- 历史记录在本机加密存储（AES-GCM，行级加密）
- 待办数据存放在本地 SQLite，不上传

## 许可

代码以 [GNU GPL-3.0](LICENSE) 开源：可以自由使用、修改、再分发，但基于它的软件也必须以 GPL 开源。

上游版权归 Typefree 作者所有；Typetodo 的修改部分版权归 liuyejinghong 所有。

## English

Typetodo is a voice-driven todo app for macOS, derived from Typefree 3.0.14 (GPL-3.0). Hold a hotkey, speak, release — dictation is polished by an LLM and typed into the focused app, exactly as upstream. On top of that, ⌘ + left-button long-press turns a spoken sentence into structured todos stored in local SQLite.

Phase 1 is bring-your-own-API-key and fully local; no self-hosted backend.

Build: macOS 14.0+, Xcode 26.3+ — `cd app && ./scripts/fetch-sparkle.sh && ./build.sh`. Licensed under GPL-3.0. The Typefree name, icon and website are not covered by the license.
