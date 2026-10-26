#!/usr/bin/env python3
"""静态校验 App 层不变量，供页面重构前后比对。

用法:
    python3 tools/check_app_invariants.py <Sources 目录>

检查:
  1. 每个 #selector(xxx) 都能找到对应的 @objc 方法
  2. Page 枚举的每个 case 都有对应的 build 分支
"""
import re
import sys
from pathlib import Path


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def main(src: Path) -> int:
    files = sorted(src.rglob("*.swift"))
    if not files:
        print(f"no swift files under {src}")
        return 2

    sources = {f: strip_comments(f.read_text()) for f in files}
    selectors = {}
    objc_funcs = set()

    external = 0
    for f, text in sources.items():
        for raw in re.findall(r"#selector\(\s*([^)]*?)\s*\)", text):
            if raw.startswith("getter:") or raw.startswith("setter:"):
                external += 1
                continue
            name = raw.split("(")[0].split(":")[0].strip()
            if not name or "." in name:
                external += 1
                continue
            selectors.setdefault(name, set()).add(f.name)
        for name in re.findall(r"@objc(?:\([^)]*\))?\s+(?:private\s+|fileprivate\s+|internal\s+)?func\s+(\w+)", text):
            objc_funcs.add(name)
        for name in re.findall(r"override\s+func\s+(\w+)", text):
            objc_funcs.add(name)

    orphans = {s: v for s, v in selectors.items() if s not in objc_funcs}

    page_cases, build_cases = set(), set()
    for text in sources.values():
        m = re.search(r"enum Page: CaseIterable \{(.*?)\n    \}", text, re.S)
        if m:
            page_cases = set(re.findall(r"^\s{8}case (\w+)", m.group(1), re.M))
        m2 = re.search(r"switch page \{(.*?)\n        \}", text, re.S)
        if m2:
            build_cases = set(re.findall(r"case \.(\w+):", m2.group(1)))

    missing_build = page_cases - build_cases - {"support"}

    print(f"files: {len(files)}")
    print(f"local selectors: {len(selectors)}  external: {external}  objc funcs: {len(objc_funcs)}")
    print(f"orphan selectors: {len(orphans)}")
    for name, where in sorted(orphans.items()):
        print(f"  ORPHAN #{name} (in {', '.join(sorted(where))})")
    print(f"page cases: {len(page_cases)}  build branches: {len(build_cases)}")
    print(f"pages without build branch: {sorted(missing_build) or 'none'}")

    return 1 if orphans or missing_build else 0


if __name__ == "__main__":
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "app/Sources")
    sys.exit(main(root))
