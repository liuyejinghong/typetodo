#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/Typetodo Install.app"
TARGET_APP="/Applications/Typetodo.app"
# 上游旧名（Typefree / Voice Polish）的安装，顺手清掉避免两份并存
OLD_TARGET_APPS=("/Applications/Typefree.app" "/Applications/Voice Polish.app")

bash "$ROOT_DIR/build.sh"

if [ ! -d "$APP_DIR" ]; then
  echo "ERROR: Missing built app at $APP_DIR"
  exit 1
fi

osascript -e 'tell application "Typetodo" to quit' >/dev/null 2>&1 || true
osascript -e 'tell application "Typefree" to quit' >/dev/null 2>&1 || true
osascript -e 'tell application "Voice Polish" to quit' >/dev/null 2>&1 || true
sleep 1

for old in "${OLD_TARGET_APPS[@]}"; do
  rm -rf "$old"
done

# 先删再拷：直接 ditto 覆盖已安装的 App 会被 macOS「应用管理」保护拦下（Operation not permitted）；
# 整体删除后重拷不受拦，且同一 Developer ID 签名，麦克风/辅助功能权限不会重新索要。
rm -rf "$TARGET_APP"
ditto "$APP_DIR" "$TARGET_APP"

echo "Installed to $TARGET_APP"
codesign -dv --verbose=2 "$TARGET_APP" 2>&1 | awk -F= '
  /^Identifier=/ { print "  Identifier: " $2 }
  /^Authority=/ && !seen[$2]++ { print "  Authority: " $2 }
  /^TeamIdentifier=/ { print "  Team: " $2 }
'
