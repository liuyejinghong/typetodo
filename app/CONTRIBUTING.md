# 参与 Typetodo

Typetodo 是个人主导的项目（一人 + AI 协作开发），基于 Typefree 3.0.14 二次开发而成。

## 提 Issue

最有用的是**可复现的问题**：你说的话、识别出来的文字、期望的结果；或者复现步骤 + 截图。
功能想法、崩溃日志、兼容性问题也都欢迎，中英文都行。

## Pull Request

当前阶段**不承诺合并外部 PR**。项目正处在结构改造期（设置窗拆分、待办子系统落地），
大块外部代码会显著增加冲突成本。

以下类型可以直接提：

- 错别字、注释、文档修正
- 明确的上游 bug（尤其是识别/润色质量问题）
- 兼容性修复

提交即视为你同意以 GPL-3.0 分发你的改动。

## 本地开发

```bash
cd app
./scripts/fetch-sparkle.sh                       # 首次
./build.sh                                       # 构建
bash scripts/install_app.sh                      # 装到 /Applications
cd TypetodoCore && swift test \
  --disable-sandbox -Xswiftc -Xfrontend -Xswiftc -disable-sandbox
```

改动 UI 后请跑一遍结构不变量检查（selector 孤儿 / 页面分支缺失），在仓库根目录执行：

```bash
python3 tools/check_app_invariants.py app/Sources
```

改润色或待办抽取的提示词时，请用真实用例对比效果，一次只改一处。

## 代码来源

上游 Typefree 的版权归其作者所有，Typetodo 的修改部分归 liuyejinghong 所有，整体以 GPL-3.0 分发。
