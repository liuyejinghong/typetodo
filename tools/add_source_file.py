#!/usr/bin/env python3
"""往 Typetodo.xcodeproj 里加一个 Swift 源文件（工程用显式文件引用，不是自动同步组）。

用法:
    python3 tools/add_source_file.py app/Sources/UI/Components/VPButton.swift

做四件事：
  1. PBXBuildFile 段加一条
  2. PBXFileReference 段加一条
  3. 挂到对应 PBXGroup（按目录自动建组，组的 path 相对 Sources）
  4. 加进 PBXSourcesBuildPhase 的 files

ID 由文件路径哈希生成，重复执行是幂等的（已存在就跳过）。
"""
import hashlib
import re
import sys
from pathlib import Path

PBX = Path("app/Typetodo.xcodeproj/project.pbxproj")
SOURCES_GROUP_ID = "AF177EAF6FE4CE64620733E6"   # 现有的 Sources 组
SOURCES_PHASE_ID = "48769FF62140F682382AB130"   # 现有的 Sources 编译阶段


def make_id(path: str, salt: str) -> str:
    return hashlib.sha1(f"{salt}:{path}".encode()).hexdigest()[:24].upper()


def group_children_insert_point(text: str, group_id: str) -> int:
    """组定义形如 `\t\t<ID> /* Name */ = {`；组引用是 4 个 tab。只认定义。"""
    m = re.search(r"\n\t\t" + group_id + r" /\* [^*]*\*/ = \{\n(?:.*?\n)?\t\t\tchildren = \(", text)
    if not m:
        raise SystemExit(f"找不到组定义 {group_id}")
    return m.end()


def main(rel: str) -> int:
    p = Path(rel)
    if not p.exists():
        print(f"❌ 文件不存在: {rel}")
        return 1
    # 统一成 app 内的相对路径
    parts = p.parts
    if parts[0] != "app":
        print("❌ 路径应以 app/ 开头")
        return 1
    inside = Path(*parts[1:])                       # Sources/UI/Components/VPButton.swift
    if inside.parts[0] != "Sources":
        print("❌ 只处理 Sources/ 下的文件")
        return 1
    name = p.name
    sub_dir = inside.parent                          # Sources/UI/Components
    # 组的 path 相对 Sources 组
    group_path = str(sub_dir)[len("Sources/"):] if str(sub_dir) != "Sources" else None

    text = PBX.read_text()
    build_id = make_id(rel, "build")
    file_id = make_id(rel, "file")

    if f"/* {name} */" in text:
        print(f"⏭️  已存在，跳过: {name}")
        return 0

    # 1) PBXBuildFile
    text = text.replace(
        "/* Begin PBXBuildFile section */\n",
        f"/* Begin PBXBuildFile section */\n"
        f"\t\t{build_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {name} */; }};\n",
        1,
    )

    # 2) PBXFileReference
    text = text.replace(
        "/* Begin PBXFileReference section */\n",
        f"/* Begin PBXFileReference section */\n"
        f"\t\t{file_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n",
        1,
    )

    # 3) 组：需要时逐级创建
    if group_path is None:
        parent_group = SOURCES_GROUP_ID
    else:
        parent_group = SOURCES_GROUP_ID
        acc = []
        for comp in group_path.split("/"):
            acc.append(comp)
            gid = make_id("/".join(acc), "group")
            if f"{gid} /* {comp} */" not in text:
                path_attr = comp if len(acc) == len(group_path.split("/")) else None
                # 组的 path 以「父组」为基准：顶层组用 "UI"，子组用 "Components"
                text = text.replace(
                    "/* End PBXGroup section */",
                    f"\t\t{gid} /* {comp} */ = {{\n"
                    f"\t\t\tisa = PBXGroup;\n"
                    f"\t\t\tchildren = (\n\t\t\t);\n"
                    f"\t\t\tpath = {path_attr or comp};\n"
                    f"\t\t\tsourceTree = \"<group>\";\n"
                    f"\t\t}};\n"
                    f"/* End PBXGroup section */",
                    1,
                )
                # 挂到父组的 children
                end = group_children_insert_point(text, parent_group)
                text = text[:end] + f"\n\t\t\t\t{gid} /* {comp} */," + text[end:]
            parent_group = gid

    # 文件本身挂到最终父组
    end = group_children_insert_point(text, parent_group)
    text = text[:end] + f"\n\t\t\t\t{file_id} /* {name} */," + text[end:]

    # 4) Sources 阶段
    idx = text.index(f"{SOURCES_PHASE_ID} /* Sources */ = {{")
    end = text.index("files = (", idx)
    text = text[: end + len("files = (")] + f"\n\t\t\t\t{build_id} /* {name} in Sources */," + text[end + len("files = ("):]

    PBX.write_text(text)
    print(f"✅ 已加入工程: {rel}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
