#!/bin/bash
# 本地开发用签名：给 .app 换一个**稳定身份**，让 macOS 的权限授权能跨重编保留。
#
# 为什么需要它：ad-hoc 签名（CODE_SIGN_IDENTITY="-"）的 designated requirement 是
# cdhash，每次编译都变。辅助功能/麦克风这类 TCC 授权是绑在该 requirement 上的，
# 于是每次重编都要重新授权，而且「系统设置 → 辅助功能」里会堆出一串同名条目。
# 用 Apple Development 证书签名后，requirement 变成
#   identifier "app.typetodo.mac" and certificate leaf[subject.CN] = "..."
# 与二进制内容无关，授权就稳住了。
#
# 注意：不能加 --options runtime（硬化运行时）。Debug 构建带有独立的
# Typetodo.debug.dylib，硬化运行时的库校验要求主二进制与 dylib 的 Team ID 一致，
# 只签外层 .app 会导致 dyld 拒绝加载、启动即崩：
#   Library not loaded: @rpath/Typetodo.debug.dylib
#   Reason: mapping process and mapped file have different Team IDs
# 正式分发（Developer ID + 公证）才需要 runtime，走 build.sh。
set -euo pipefail

APP="${1:?用法: sign-dev.sh <path/to/App.app> [签名身份]}"
IDENTITY="${2:-${DEVELOPMENT_SIGN_IDENTITY:-}}"

if [ -z "$IDENTITY" ]; then
    IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ { print $2; exit }')"
fi
if [ -z "$IDENTITY" ]; then
    echo "❌ 没找到 Apple Development 证书；请在 Xcode → Settings → Accounts 登录开发者账号。"
    exit 1
fi

echo "🔏 签名身份：$IDENTITY"

sign() { /usr/bin/codesign --force --sign "$IDENTITY" "$1"; }

SP="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
if [ -d "$SP" ]; then
    # 由内到外：先 XPC 服务，再辅助工具，最后框架本身
    for xpc in "$SP/XPCServices/"*.xpc; do
        [ -e "$xpc" ] && sign "$xpc"
    done
    [ -e "$SP/Autoupdate" ] && sign "$SP/Autoupdate"
    [ -e "$SP/Updater.app" ] && sign "$SP/Updater.app"
    sign "$APP/Contents/Frameworks/Sparkle.framework"
fi

# Debug 构建的主逻辑在独立 dylib 里，必须先签它
for dylib in "$APP/Contents/MacOS/"*.dylib; do
    [ -e "$dylib" ] && sign "$dylib"
done

# 最后签 app 本体，带上麦克风 entitlement
/usr/bin/codesign --force \
    --entitlements "$(dirname "$0")/../Resources/Typetodo.entitlements" \
    --sign "$IDENTITY" "$APP"

/usr/bin/codesign --verify --strict "$APP"
echo "✅ 签名完成"
/usr/bin/codesign -dv --verbose=2 "$APP" 2>&1 | awk -F= '
    /^Identifier=/ { print "   Identifier: " $2 }
    /^TeamIdentifier=/ { print "   Team: " $2 }
    /^Authority=/ && !seen[$2]++ { print "   Authority: " $2 }'
