#!/usr/bin/env bash
# xcodebuild 包装器。
#
# 为什么需要它：本机（以及任何外层已套 Seatbelt 的环境）里，xcodebuild 调 SwiftPM
# 评估 Package.swift 时会再起一层 sandbox-exec，macOS 拒绝嵌套 Seatbelt，报
#   xcodebuild: error: Could not resolve package dependencies:
#   sandbox-exec: sandbox_apply: Operation not permitted
# 这两个 -IDE... 参数是 NSUserDefaults 开关，只能从命令行传，用来关掉清单与插件沙箱。
set -euo pipefail

exec xcodebuild \
  -IDEPackageSupportDisableManifestSandbox=1 \
  -IDEPackageSupportDisablePluginExecutionSandbox=1 \
  "$@"
