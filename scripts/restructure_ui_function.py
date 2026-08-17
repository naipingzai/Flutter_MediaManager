#!/usr/bin/env python3
"""Aves 项目结构重塑脚本：ui/function 二分 + function 扁平化

- UI 代码 -> lib/ui/{view,widgets,theme,image_providers}/...（保留子结构）
- 功能代码 -> lib/function/（扁平，命名 function_<分类>_<名字>.dart，路径段与文件名同名时折叠）
- 不动：lib/main*.dart、根文件、lib/l10n、lib/l10ngen
- 用法：python3 scripts/restructure_ui_function.py [--dry]
"""
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / 'lib'
PKG = 'flutter_media_view'

# UI 目录映射（保留子结构）
UI_MAP = {
    'view': 'view',
    'widgets': 'widgets',
    'theme': 'theme',
    'image_providers': 'image_providers',
}
# 功能目录（扁平化到 function/，加 function_ 前缀）
FUNC_DIRS = {'model', 'services', 'utils', 'convert', 'geo', 'ref', 'locale'}
# 完全不动的目录（l10n.yaml 引用）
KEEP_DIRS = {'l10n', 'l10ngen'}

DRY = '--dry' in sys.argv


def new_func_name(sub_parts, stem):
    """生成 function_xxx.dart 名称；路径段与文件名同名时折叠"""
    segs = [p for p in sub_parts if p != stem]
    return 'function_' + '_'.join(segs + [stem])


# 1. 收集映射：old import path (不含 .dart) -> new import path (不含 .dart)
# 两阶段：先算候选名，冲突的自动回退为带顶级目录名的命名（function_<top>_...）
candidates = []  # (old abs, old import, new import)

for top in sorted(set(UI_MAP) | FUNC_DIRS):
    topdir = LIB / top
    if not topdir.is_dir():
        continue
    for f in sorted(topdir.rglob('*.dart')):
        rel = f.relative_to(LIB)
        parts = rel.parts  # e.g. ('model', 'entry', 'extensions', 'catalog.dart')
        stem = f.stem
        old_import = str(rel.with_suffix('')).replace(os.sep, '/')
        if top in UI_MAP:
            sub = parts[1:-1]
            new_import = 'ui/' + UI_MAP[top] + ('/' + '/'.join(sub) if sub else '') + '/' + stem
        else:
            name = new_func_name(parts[1:-1], stem)
            new_import = f'function/{name}'
        candidates.append((f, old_import, new_import))

# 统计冲突并对冲突项回退为 function_<top>_... 命名
from collections import Counter
name_count = Counter(imp for _, _, imp in candidates)
conflicts = {imp for imp, c in name_count.items() if c > 1}

mapping = {}
moves = []  # (old abs, new abs)
seen_targets = {}
for f, old_import, new_import in candidates:
    if new_import in conflicts:
        top = old_import.split('/')[0]
        if top in UI_MAP:
            print(f'UI 冲突无法自动回退: {new_import} ({f})')
            sys.exit(1)
        # function/<name> -> function/function_<top>_<name去前缀>
        name = new_import.split('/', 1)[1]
        assert name.startswith('function_')
        stripped = name[len('function_'):]
        new_import = f'function/function_{top}_{stripped}'
    if new_import in seen_targets:
        print(f'CONFLICT: {new_import}\n  {f}\n  {seen_targets[new_import]}')
        sys.exit(1)
    seen_targets[new_import] = f
    mapping[old_import] = new_import
    if new_import.startswith('function/'):
        new_abs = LIB / (new_import + '.dart')
    else:
        rel_parts = new_import.split('/')
        new_abs = LIB.joinpath(*rel_parts).with_suffix('.dart')
    moves.append((f, new_abs))

if conflicts:
    print(f'自动解决的命名冲突: {sorted(conflicts)}')

print(f'待移动文件数: {len(moves)}')
print(f'  UI: {sum(1 for _, n in moves if str(n).startswith(str(LIB / "ui")))}')
print(f'  function: {sum(1 for _, n in moves if str(n).startswith(str(LIB / "function")))}')

# 2. git mv
for old, new in moves:
    if DRY:
        continue
    new.parent.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(['git', 'mv', str(old), str(new)], cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        print(f'git mv FAIL: {old} -> {new}\n{r.stderr}')
        sys.exit(1)

# 3. 重写 import/export（lib + test + test_driver）
import_re = re.compile(rf'package:{PKG}/([\w/]+)\.dart')
rewritten = 0
misses = set()


def repl(m):
    path = m.group(1)
    if path in mapping:
        return f'package:{PKG}/{mapping[path]}.dart'
    top = path.split('/')[0]
    if top in KEEP_DIRS or '/' not in path:
        return m.group(0)  # 保留目录 / 根文件
    misses.add(path)
    return m.group(0)


scan_dirs = [LIB, ROOT / 'test', ROOT / 'test_driver']
for sd in scan_dirs:
    if not sd.is_dir():
        continue
    for f in sd.rglob('*.dart'):
        content = f.read_text(encoding='utf-8')
        new_content = import_re.sub(repl, content)
        if new_content != content:
            rewritten += 1
            if not DRY:
                f.write_text(new_content, encoding='utf-8')

print(f'重写 import 的文件数: {rewritten}')
if misses:
    print('未命中路径（需人工检查）:')
    for p in sorted(misses):
        print(' ', p)
    sys.exit(1)
print('DRY RUN OK' if DRY else 'OK')
