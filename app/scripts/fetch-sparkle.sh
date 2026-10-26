#!/usr/bin/env bash
# 拉取并解压 Sparkle 到 app/vendor/Sparkle。
#
# 为什么不用 SwiftPM 远程依赖：本机网络拉 GitHub 的 git 仓库极慢（几十分钟），
# 而 codeload 的源码包能稳定下载。依赖目录不进仓库（22MB），首次构建前跑一次本脚本即可。
set -euo pipefail

VERSION="${SPARKLE_VERSION:-2.9.3}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/vendor/Sparkle"
URL="https://codeload.github.com/sparkle-project/Sparkle/tar.gz/refs/tags/${VERSION}"

if [ -f "$DEST/Package.swift" ]; then
    echo "Sparkle ${VERSION} 已存在：$DEST"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "下载 Sparkle ${VERSION}…"
curl -fSL --retry 3 -o "$TMP/sparkle.tar.gz" "$URL"

mkdir -p "$ROOT/vendor"
rm -rf "$DEST"
mkdir -p "$DEST"
tar -xzf "$TMP/sparkle.tar.gz" -C "$DEST" --strip-components=1

echo "完成：$DEST"
