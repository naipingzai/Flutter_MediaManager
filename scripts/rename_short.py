#!/usr/bin/env python3
"""精简文件命名：去掉 ui_/function_ 前缀 + 去掉与父目录重复的单词段"""
import subprocess, sys
from pathlib import Path
from collections import Counter

ROOT = Path('.')
PKG = 'flutter_media_view'
DRY = '--dry' in sys.argv

# 收集所有文件及其候选新名
files = []  # [(abs, parent_dir, stem)]
for root_name in ['ui', 'function']:
    root = ROOT / 'lib' / root_name
    for f in sorted(root.rglob('*.dart')):
        if f.parent == root:
            continue
        parent_dir = f.parent.name
        stem = f.stem
        prefix = f'{root_name}_'
        if stem.startswith(prefix):
            stem = stem[len(prefix):]
        if stem.startswith(parent_dir + '_'):
            stem = stem[len(parent_dir) + 1:]
        if parent_dir == 'common' and stem.startswith('widgets_'):
            stem = stem[8:]
        files.append((f, parent_dir, stem))

# 冲突检测 + 消歧
counts = Counter(s for _, _, s in files)
dup = {s for s, c in counts.items() if c > 1}

mapping = {}
moves = []
for f, parent_dir, stem in files:
    new_stem = stem
    if stem in dup:
        new_stem = f'{parent_dir}_{stem}'
    new_name = new_stem + '.dart'
    if new_name != f.name:
        mapping[str(f.relative_to(ROOT))] = new_name
        moves.append((f, f.parent / new_name))

print(f'待重命名: {len(moves)}')
if dup:
    print(f'冲突消歧: {len(dup)} 个')
    for s in sorted(dup):
        print(f'  {s}.dart')

if DRY:
    print('DRY RUN 示例:')
    for k, v in list(mapping.items())[:10]:
        print(f'  {Path(k).name} -> {v}')
    sys.exit(0)

# git mv
for src, dst in moves:
    if dst.exists():
        print(f'跳过: {dst}')
        continue
    r = subprocess.run(['git', 'mv', str(src), str(dst)], capture_output=True, text=True)
    if r.returncode != 0:
        print(f'FAIL: {src.name} -> {dst.name}')
        sys.exit(1)

# 更新 import
dir_map = {}
for root_name in ['ui', 'function']:
    for f_src, dst in moves:
        old_import = f'{root_name}/{f_src.name}'
        new_import = f'{root_name}/{dst.name}'
        if old_import not in dir_map:
            dir_map[old_import] = new_import

changed = 0
for sd in [ROOT/'lib', ROOT/'test']:
    for f in sd.rglob('*.dart'):
        try:
            content = f.read_text()
            new_content = content
            for old_imp, new_imp in dir_map.items():
                new_content = new_content.replace(f'package:{PKG}/{old_imp}', f'package:{PKG}/{new_imp}')
            if new_content != content:
                f.write_text(new_content)
                changed += 1
        except Exception as e:
            print(f'ERR: {f}: {e}')

print(f'更新引用文件数: {changed}')
print('DONE')
