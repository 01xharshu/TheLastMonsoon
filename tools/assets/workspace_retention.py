"""Shared conservative reference and dirty-file protection for maintenance."""
from pathlib import Path
import subprocess
ROOT = Path(__file__).resolve().parents[2]
TEXT_SUFFIXES = {'.md','.json','.gd','.gdshader','.tscn','.tres','.py','.html','.svg','.toml','.cfg','.godot','.import','.txt','.csv','.sh','.yml','.yaml','.xml'}
EXCLUDED = {'.git','.godot','node_modules','__pycache__','.venv'}

def dirty_paths():
    raw = subprocess.check_output(['git','status','--porcelain=v1','-z','--untracked-files=all'],cwd=ROOT).decode().split('\0')
    found=set(); index=0
    while index < len(raw):
        entry=raw[index]; index+=1
        if not entry: continue
        found.add(entry[3:])
        if 'R' in entry[:2] or 'C' in entry[:2]:
            if index < len(raw): found.add(raw[index]); index+=1
    return found

def is_dirty(relative, dirty):
    return any(relative == item or (item.endswith('/') and relative.startswith(item)) for item in dirty)

def references_to(candidates, ignore=()):
    """Scan the whole checkout, including code/scenes/import/config outside docs.
    Basename matches are deliberately conservative; collisions retain extra files.
    Generated retention inventories are records of cleanup, not dependencies.
    """
    import os
    candidates=[Path(p) for p in candidates]
    matches={p:[] for p in candidates}
    ignored={str(Path(p).resolve()) for p in ignore}
    for folder,dirs,files in os.walk(ROOT):
        dirs[:]=[d for d in dirs if d not in EXCLUDED]
        for name in files:
            path=Path(folder)/name
            if str(path.resolve()) in ignored: continue
            if path.suffix not in TEXT_SUFFIXES or path.stat().st_size > 12*1024*1024: continue
            relative=str(path.relative_to(ROOT))
            if path.suffix=='.json' and 'retention' in path.name: continue
            data=path.read_text(errors='replace')
            for target in candidates:
                if path==target: continue
                wanted=str(target.relative_to(ROOT))
                if wanted in data or target.name in data:
                    matches[target].append(relative)
    return matches
