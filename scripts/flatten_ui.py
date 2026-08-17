#!/usr/bin/env python3
"""UI 扁平化脚本：把 lib/ui/{view,widgets,theme,image_providers}/** 全部拍平到 lib/ui/ 单层。

命名：ui_<路径段>_<stem>.dart（剔除无信息量的 'src' 段、与文件名同名的段；冲突时回退为完整段）。
barrel 文件 view/view.dart 的相对 export 一并重写为 package 形式。
用法：python3 scripts/flatten_ui.py [--dry]
"""
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / 'lib'
PKG = 'flutter_media_view'
UI = LIB / 'ui'
DRY = '--dry' in sys.argv


def new_name(sub_parts, stem):
    segs = [p for p in sub_parts if p not in ('src', stem)]
    return 'ui_' + '_'.join(segs + [stem])


# 1. 收集映射
candidates = []  # (abs, old_import, new_import)
for f in sorted(UI.rglob('*.dart')):
    rel = f.relative_to(LIB)
    parts = rel.parts  # ('ui', 'view', 'src', 'storage', 'x.dart')
    stem = f.stem
    old_import = str(rel.with_suffix('')).replace(os.sep, '/')
    sub = list(parts[1:-1])
    candidates.append((f, old_import, 'ui/' + new_name(sub, stem)))

# 冲突回退：用完整段（仅剔除 'src'）
count = Counter(imp for _, _, imp in candidates)
conflicts = {imp for imp, c in count.items() if c > 1}

mapping = {}
moves = []
seen = {}
for f, old_import, new_import in candidates:
    if new_import in conflicts:
        rel = f.relative_to(LIB)
        stem = f.stem
        sub = [p for p in rel.parts[1:-1] if p != 'src']
        new_import = 'ui/' + 'ui_' + '_'.join(sub + [stem])
    if new_import in seen:
        print(f'CONFLICT(unresolved): {new_import}\n  {f}\n  {seen[new_import]}')
        sys.exit(1)
    seen[new_import] = f
    mapping[old_import] = new_import
    moves.append((f, LIB / (new_import + '.dart')))

if conflicts:
    print(f'回退命名的冲突数: {len(conflicts)}')
print(f'待移动: {len(moves)}')

# 3. 重写引用：
#    a) package import（lib + test + test_driver）
#    b) 原 view/view.dart barrel 内的相对 export（'src/x.dart' 相对 lib/ui/view/ 解析）
pkg_re = re.compile(rf'package:{PKG}/([\w/]+)\.dart')
barrel_rel_re = re.compile(r"(?P<stmt>[ie][mx]port )'(?P<path>[\w][\w/]*)\.dart'")


def map_pkg(path):
    return mapping.get(path)


rewritten = 0
misses = set()
for sd in [LIB, ROOT / 'test', ROOT / 'test_driver']:
    if not sd.is_dir():
        continue
    for f in sd.rglob('*.dart'):
        content = f.read_text(encoding='utf-8')
        # package 形式
        def pkg_repl(m):
            p = m.group(1)
            if p in mapping:
                return f'package:{PKG}/{mapping[p]}.dart'
            if p.startswith('ui/'):
                misses.add(p)
            return m.group(0)
        new_content = pkg_re.sub(pkg_repl, content)
        # 相对 export/import（barrel 与同目录引用）——仅对 lib 内文件处理
        in_lib = str(f).startswith(str(LIB))
        if in_lib:
            base_dir = f.parent

            def rel_repl(m):
                stmt, path = m.group('stmt'), m.group('path')
                target = (base_dir / path).resolve()
                try:
                    rel_to_lib = target.relative_to(LIB)
                except ValueError:
                    return m.group(0)
                key = str(rel_to_lib.with_suffix('')).replace(os.sep, '/')
                if key in mapping:
                    return f"{stmt}'package:{PKG}/{mapping[key]}.dart'"
                return m.group(0)

            new_content = barrel_rel_re.sub(rel_repl, new_content)
        if new_content != content:
            rewritten += 1
            if not DRY:
                f.write_text(new_content, encoding='utf-8')

# git mv（在内容重写之后执行，保证相对路径按旧位置解析）
for old, new in moves:
    if DRY:
        continue
    new.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(['git', 'mv', str(old), str(new)], cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        print(f'git mv FAIL: {old} -> {new}\n{r.stderr}')
        sys.exit(1)

print(f'重写引用文件数: {rewritten}')
if misses:
    print('未命中的 ui 路径:')
    for p in sorted(misses):
        print(' ', p)
    sys.exit(1)
print('DRY RUN OK' if DRY else 'OK')
