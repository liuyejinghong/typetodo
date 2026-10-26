# Typefree 二次开发：授权路径、重写规模与 Typetodo 功能方案

> 版本 v0.1 ｜ 2026-10-26 ｜ 承接《01-typefree-项目拆解》
> 本文回答三个问题：**要不要开源**、**不开放重写多大**、**语音建待办怎么做**

---

## 一、GPL 到底管什么

先说结论：**GPL 约束的是「分发」，不是「使用」，也不是「修改」。**

| 你的场景 | 是否触发 GPL 义务 | 说明 |
|---|---|---|
| 自己改着用、公司内部几个人装 | ❌ 不需要开源 | GPLv3 明确允许「为自身使用而修改」，不分发 = 无义务 |
| 内部私有部署 / 只给团队装 | ❌ 不需要开源 | 只要不向「外部主体」提供副本 |
| 打包 DMG 发给朋友 / 客户 / 公开下载 | ✅ 必须开源 | 分发二进制即触发，须提供完整对应源码 |
| 卖给客户（哪怕收费） | ✅ 必须开源 | 收费不影响 GPL，买到的人有权再分发 |
| 只做云端服务，用户不装客户端 | ⚠️ 不受 GPL 约束 | 这是 GPL 与 AGPL 的关键差别；但你是桌面 App，用不上这条 |
| 复制它的代码进新项目，再闭源 | ✅ 侵权 | 复制 = 衍生作品，必须 GPL |

**几条容易踩的细节**：

1. **改功能不等于"新作品"**。加 Todo、删会员、换 UI，只要还含上游代码，就是衍生作品，整体必须 GPL-3.0。
2. **发布过就收不回**。某个版本一旦以 GPL 发布，任何人都可以永久再分发它；后续闭源只能约束"新版本"，旧版本管不了。
3. **必须保留版权声明**，并说明你改了什么（GPLv3 §5a）。不能抹掉原作者的版权头。
4. **不能再用它的名字和图标**——这一条你换 Typetodo 已经解决了；但官网文案、`appcast.xml` 的更新源也要换。
5. **Sparkle 的更新签名密钥必须换成你自己的**，否则你能被上游的更新通道覆盖。

> 我不是律师，以上为工程视角的合规判断，正式商用前请让法务过一遍。

---

## 二、三条路径

| | 方案 A：跟随 GPL | 方案 B：Clean-room 重写 | 方案 C：先 A 后 B |
|---|---|---|---|
| 做法 | fork，改名换图标，开源发布 | 只借鉴思路与交互，代码全部自研 | 先用 fork 验证产品，起量后重写对外版 |
| 合规成本 | 极低 | 中（需留存自研证据） | 高（两套代码） |
| 商业模型 | 卖服务（额度/会员），代码公开 | 可卖软件、可闭源 | 早期开源、后期闭源（社区观感差） |
| 一次性投入 | 3~5 人日 | 35~45 人日 | 3~5 + 40 人日 |
| 新增 Todo 功能 | 8~12 人日（复用现有管线） | 含在上面的重写里 | 两次 |
| 风险 | 竞品可直接拿走你的代码 | 踩坑重来，AX/粘贴这些脏活最费时间 | 早期版本永久开源，等于白送 |

**我的建议：走 A。**

理由不是"省钱"，而是**你的商业模式本来就不在代码上**：你计划二期做试用额度与会员，卖的是**服务端配额与免配置体验**，这部分 GPL 完全不管。而闭源能带来的好处（防止抄袭）在 1~2 人团队阶段基本是幻觉——真正会被抄走的是产品判断，不是 3 万行 Swift。

**什么情况下必须选 B**：① 要卖给企业客户且对方要求源码保密条款；② 要融资/被收购，代码资产必须干净；③ 你就是不想让别人白嫖。这三种情况下，B 的 35~45 人日就是必要成本。

---

## 三、重写规模（方案 B 的账）

上游 33,247 行里，真正需要「重写」的是**行为**，不是行数。有效功能代码约 15,000 行，自研估算 10,000 行左右。

| 模块 | 上游行数 | 自研估算 | 难度 | 说明 |
|---|---|---|---|---|
| 音频采集 / 电平 / WAV·M4A 编码 | ~700 | 500 | 低 | AVAudioEngine 套路固定 |
| 云端识别客户端（火山同步+异步、百炼） | 730 | 700 | 中 | 协议细节多但文档齐全 |
| 分片 / 边录边发 / 拼接 | 564 | 450 | **中高** | 边界情况多（静音、误判、超时） |
| 润色（多 provider + 提示词 + 容错） | 1,210 | 700 | 中 | 提示词要重新调 |
| 配置 / Keychain / 历史加密 | 588 | 500 | 低中 | AES-GCM 逐行加密要写对 |
| 全局热键 / 鼠标长按手势 | 1,445 | 700 | **高** | 系统事件与权限的坑最多 |
| AX 焦点探测 / 文本投递 | 789 | 600 | **高** | 微信、网页、远程桌面各有特例 |
| 浮窗 / 设置 / 历史 UI | ~9,000 | 3,500 | 中 | 量大但不难 |
| **Todo 解析 + 清单 UI（新增）** | 0 | 2,100 | 中高 | 见第四节 |
| 签名 / 公证 / 打包 / 更新 | ~200 | 200 | 低 | 一次性配置 |
| **合计** | ~15,000 | **~10,000** | | **35~45 人日**（单人 7~9 周） |

**三个"贵"在哪**（这才是重写的真实成本，不是打字量）：

1. **AX 焦点探测**：读不到结构时要不要粘？微信不暴露 AX 树，网页焦点可能在正文。上游用了 460 行 + 大量注释在解这个题，重写等于重新踩一遍。
2. **粘贴与剪贴板**：Electron / 远程桌面读剪贴板慢，还原早了会把用户原内容粘进去；还要打 `TransientType` 标记，否则污染剪贴板历史。
3. **全局手势**：热键与 Esc 拦截会互相吞键；鼠标手势要豁免自己的窗口，否则点浮窗也触发。

**能大幅压缩的部分**：UI。上游 7,717 行设置窗是"手写 AppKit 控件"，你用 SwiftUI 重做同样的页面大概 1,500 行就够，而且更好改。

---

## 四、新增功能：语音建待办

### 4.1 触发手势：右键长按有结构性冲突

你暂定「长按鼠标右键」，这里必须先说清楚代价：

**冲突点**：macOS 的右键菜单是在 **`rightMouseDown` 那一刻**弹出的，不等松手。所以"长按右键 0.5 秒"这个动作，在系统看来已经是"用户要开菜单了"。要实现它，只有两条路：

| 做法 | 实现 | 代价 |
|---|---|---|
| 吞掉 `rightMouseDown`，判定长按后再决定 | `CGEventTap` 拦截，短按则补发一对合成事件 | 菜单会延迟弹出；补发的合成事件在部分 App（浏览器、Electron）里位置/状态会失真；偶发"右键失灵"投诉 |
| 不吞事件，改用"右键按住 + 拖动" | 只在拖动超阈值时接管 | 拖动时系统菜单已经打开，会高亮菜单项，体验更糟 |

**我的建议（已按用户决策修正）**：

1. **原版手势一个都不动**：输入框长按 = 听写，空白处长按 = 问 AI。
2. **待办用 `⌘` + 左键长按**：⌘ 是"待办修饰键"，只在非可点击区域生效，短按完全不干预系统行为。
3. **右键长按不做**：右键菜单在 `rightMouseDown` 即弹出，要长按就得吞事件再合成，必然失真。
4. **兜底**：`⌥Space` 热键 + 菜单栏两个入口。

> 详细排查（⌘/⌥/⇧/⌃ 逐个对比系统占用）见《03-空白处长按调研与本地提醒方案》第三节。

### 4.1.1 手势映射（定稿）

| 手势 | 语义 | 说明 |
|---|---|---|
| 输入框 + 长按 | 听写 | 原版，不变 |
| 空白处 + 长按 | 问 AI | 原版，不变 |
| **`⌘` + 空白处长按** | **记待办** | 新增；只在非可点击区域生效，阈值 0.55s |
| `⌘` + 输入框长按 | 不启用 | 避免与"跳转定义/多选"冲突 |
| `⌥Space` / 菜单栏 | 记待办 / 听写 | 兜底入口 |
| 右键长按 | 不做 | 与系统右键菜单结构性冲突 |

改动量：`MouseHoldToTalkManager` 在 `mouseDown` 读 `modifierFlags` 加一条分支 + `AppDelegate` 抽 `stopRecording(intent:)`，约 30 行，原 ask 分支零改动。

### 4.2 管线改造：一条识别，两个用例

上游的 `VoicePolishPipeline` 是"识别 → 润色 → 出文本"，把 Todo 硬塞进去会变成 if-else 泥潭。正确做法是**在识别之后分叉**：

```
录音 ──▶ ASR（共享，含流式/分片/重试/失败保留）
              │
              ├──▶ 听写用例：润色 → 术语纠正 → ⌘V 投递
              │
              └──▶ 待办用例：结构化抽取 → 校验 → 确认/直接入库 → 清单
```

对应代码上就是把 `VoicePolishPipeline` 拆成 `TranscriptionService`（只管出原文）+ 两个 UseCase。**这一步在方案 A 下也要做**——否则你会在 463 行的 pipeline 里加一堆 `if isTodo`。

### 4.3 结构化契约（给模型的输出协议）

```json
{
  "title": "交周报",
  "notes": "把 Q3 的三个项目进展整理进去",
  "due_at": "2026-10-27T15:00:00+08:00",
  "due_has_time": true,
  "priority": "high",
  "list": "工作",
  "tags": ["周报"],
  "confidence": 0.86,
  "needs_confirmation": false
}
```

**四条硬规则**：

1. **时间必须由模型算，但时间基准必须我们给**。prompt 里注入 `now`（含时区与星期）+ 用户已有清单名，否则"下周一"永远算错。
2. **本地二次校验**：`due_at` 解析失败、超出 ±2 年、早于现在 → 标记 `needs_confirmation`，不静默丢弃。
3. **结构化字段优先**：不要让模型返回一段自然语言再正则抠，直接要求 JSON（provider 支持 `response_format` 就强制开启）。
4. **解析失败不丢数据**：整段原文当 `title` 入库，标 `needs_tidy`，用户回头再改。

### 4.4 置信度与确认策略

效率工具最忌"每次都要确认"。建议：

| 情况 | 行为 |
|---|---|
| `confidence ≥ 0.8` 且 title 非空 | **直接入库** + Toast「已添加：明天 15:00 交周报」，5 秒内可撤销 |
| 缺 title / 时间歧义 / 多任务 | 弹确认卡，字段可编辑，一次点击确认 |
| 解析失败 / 网络失败 | 原文入库为待办，标记待整理；**永不丢** |

### 4.5 幂等与去重

- 每次录音生成 `entry_id`（UUID），作为 todo 的 `dedupe_key`（唯一索引）。
- 用户点重试 / 网络重发 → 命中唯一键则更新而非新建。
- 一句话里说了三件事（"明天交周报、后天开会、买咖啡"）→ 一次抽取返回数组，共享同一个 `entry_id`，用 `序号` 拼 `dedupe_key`。

### 4.6 数据模型与存储

本地优先，用系统自带 `libsqlite3`（不引第三方，和上游"零依赖"风格一致）：

```sql
CREATE TABLE list (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, color TEXT,
  sort INTEGER NOT NULL DEFAULT 0, is_default INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE todo (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  notes TEXT,
  due_at INTEGER,                 -- epoch 秒，NULL = 无时间
  due_has_time INTEGER NOT NULL DEFAULT 0,  -- 0 = 全天
  priority INTEGER NOT NULL DEFAULT 1,      -- 0 低 / 1 普通 / 2 高
  list_id TEXT REFERENCES list(id),
  status INTEGER NOT NULL DEFAULT 0,        -- 0 待办 / 1 完成 / 2 归档
  source INTEGER NOT NULL DEFAULT 0,        -- 0 语音 / 1 手动
  raw_text TEXT,                            -- 识别原文，便于回溯
  audio_ref TEXT,                           -- 关联 m4a（可选）
  confidence REAL,
  dedupe_key TEXT UNIQUE,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);

CREATE INDEX idx_todo_due ON todo(status, due_at);
CREATE INDEX idx_todo_list ON todo(list_id, status);
```

音频与历史沿用上游策略：文本落 `polish_log.jsonl`（AES-GCM 逐行加密），音频落 `audio/<id>.m4a`，保留期可配。

---

## 五、分期与接口预留

### 5.1 一期（本地跑通，自带 Key）

| 能力 | 说明 |
|---|---|
| 听写 | 完整保留上游能力（热键/鼠标长按/润色/投递/历史/词库） |
| 建待办 | 语音 → 结构化 → 清单；清单/详情/完成/删除/搜索 |
| 模型 | 用户自填火山 ASR Key + 一个润色/抽取 LLM Key（Qwen 或 GLM） |
| 账号 | 无。匿名本地状态 |
| 额度 | 无。自己付费给模型厂商 |

### 5.2 二期（试用 + 会员）

- 新增服务端：`/v1/trial/start`、`/v1/usage`、`/v1/account`、转发型 `/v1/asr` `/v1/refine` `/v1/todo/extract`
- 客户端只换实现，不改 UI：`DirectXxx` → `HostedXxx`

### 5.3 一期就要预留的接口（关键）

**原则：所有"将来要联网的事"，一期都用协议 + 空实现顶住，UI 只依赖协议。**

```swift
// core/Account
protocol AccountProviding {
    var state: AccountState { get }          // 匿名 / 试用 / 会员 / 过期
    func refresh() async throws
}
struct AnonymousAccount: AccountProviding { /* 一期：恒为 .anonymous */ }

// core/Quota
protocol QuotaReporting {
    func report(_ event: UsageEvent) async    // 一期：空实现，仅本地统计
}
protocol EntitlementProviding {
    func isEnabled(_ feature: Feature) -> Bool // 一期：全部 true
}

// core/Speech & Text
protocol SpeechRecognizing { func transcribe(_ a: AudioPayload, _ o: ASROptions) async throws -> Transcript }
protocol TextRefining      { func refine(_ t: String, _ s: RefineStyle) async throws -> String }
protocol TodoExtracting    { func extract(_ t: String, _ c: ExtractionContext) async throws -> [TodoDraft] }
```

#### 5.3.1 实施修订（P0 落地后回填）

原计划是「协议 + 空实现」。读完上游实现后改为**保留实现、集中关闭**，理由：

上游那套试用/会员代码已经把二期的契约写全了——`HostedRoute.decide` 是可单测的纯函数路由、
`MembershipInfo` 是现成 DTO、`ActivationError` 与 `trial_expired` / `insufficient_quota`
是现成错误码、证书固定与额度对账也在。删掉再抽一套协议+空实现，等于把已验证的实现换成没人验证的骨架。

所以实际做法是新增 `HostedAvailability` 作为**唯一总开关**：

```swift
HostedAvailability.apiBase   // nil = 一期，没有托管通道
HostedAvailability.isEnabled // false
```

- `TrialManager.configuredAPIBase` / `LicenseManager.apiBase` 都从它取值
- `HostedRoute.current` 用它判 `hostedAvailable`，一期恒为 `.none`，即自带 Key 直连
- 构建期由 `local.build.env` 的 `TYPETODO_HOSTED_API_BASE` 注入 Info.plist；没注入时
  Xcode 留下 `$(...)` 字面量，`resolve()` 视为未配置
- 二期接回服务端 = 给这一个变量赋值，调用方一行不改

护栏测试 `HostedAvailabilityTests` 锁死了「没有通道时必须 `.none`」，并复查了有通道时
会员优先 / 自带 Key 优先 / 试用兜底三种路由仍然正确。

**路由策略**（照搬上游 `HostedRoute` 的思路，一期只会命中 `.ownKey`）：

```swift
enum Route { case ownKey, hostedTrial, hostedMember }
RoutePolicy.decide(ownKeyConfigured:hasMembership:inTrial:) -> Route
```

**二期 API 契约草案**（一期只定 DTO 与错误码，不实现）：

| 接口 | 请求 | 响应 |
|---|---|---|
| `POST /v1/trial/start` | device_id, app_version | token, days_left, char_quota |
| `POST /v1/usage` | token, kind(asr/refine/todo), chars | remaining |
| `GET /v1/account` | — | plan, expires_at, entitlements |
| `POST /v1/asr` | audio(multipart), lang | text |
| `POST /v1/refine` | text, style | text |
| `POST /v1/todo/extract` | text, now, tz, lists | drafts[] |

统一错误码：`quota_exhausted` / `trial_expired` / `unauthorized` / `rate_limited` / `upstream_error`。一期把这套错误枚举先定义好，二期直接把 HTTP 映射进来。

### 5.4 目录结构

```
typetodo/
├── app/                          # macOS App（AppKit + SwiftUI）
│   ├── Typetodo.xcodeproj/
│   └── Sources/
│       ├── App/                  # 生命周期、依赖装配（每文件 ≤300 行）
│       ├── Features/
│       │   ├── Capture/          # 手势、录音态、浮窗
│       │   ├── Dictation/        # 听写：润色结果 → 投递
│       │   ├── Todo/             # 待办：确认卡、清单、详情、搜索
│       │   └── Settings/         # 模型、快捷键、隐私、关于（拆页）
│       ├── Services/             # 投递、通知、权限、快捷键
│       └── UI/                   # 设计系统与复用控件
├── core/                         # TypetodoCore（SwiftPM，可独立测试）
│   ├── Sources/
│   │   ├── Audio/  Speech/  Text/  Todo/  Storage/
│   │   ├── Account/              # 一期空实现，二期远程
│   │   └── Diagnostics/
│   └── Tests/
├── docs/
└── research/typefree/            # 上游源码（只读，不参与构建）
```

---

## 六、排期建议（方案 A）

| 阶段 | 内容 | 人日 |
|---|---|---|
| P0 | 改名换图标、删试用/会员、切断上游更新与官网链接、本机跑通 | 3~5 |
| P1 | 拆 `VoicePolishPipeline` 为 TranscriptionService + 两个 UseCase | 2 |
| P2 | Todo 结构化（prompt + 校验 + 兜底） | 3~4 |
| P3 | 待办清单 UI（列表/详情/完成/搜索/撤销） | 4~5 |
| P4 | 手势改造（空白处=待办、⌥+空白处=问AI、热键、右键长按可选） | 1~2 |
| P5 | 本地提醒（授权、排程重建、通知动作、降级） | 2~3 |
| P6 | 二期接口骨架（协议 + 空实现 + DTO + 错误码） | 1 |
| **合计** | 一期可交付 | **16~22 人日** |

> 手势细节与提醒方案见《03-空白处长按调研与本地提醒方案》。

---

## 七、待你拍板

1. **开源策略**：确认走 A（GPL 开源、卖服务），还是必须 B（闭源、重写）？
2. **手势定案**：空白处长按 = 记待办、`⌥`+空白处长按 = 问 AI（详见 03 文档第三节），能接受吗？
3. **提醒默认值**：全天任务默认当天 09:00 提醒，合适吗？

> 本方案为产品设计参考，具体实施请结合公司合规与法务要求确认。
