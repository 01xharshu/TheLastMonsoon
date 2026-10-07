"""Remove disposable test output; dry run by default, --apply deletes.
Does not touch runtime assets, reference images, editable sources or Git history.
"""
from pathlib import Path
import argparse
import os
import re

ROOT = Path(__file__).resolve().parents[2]
MEDIA = {'.png', '.jpg', '.jpeg', '.webp', '.mp4', '.mov', '.webm', '.avi'}
VIDEO = {'.mp4', '.mov', '.webm', '.avi'}
EXCLUDED = {'.git', '.godot', 'node_modules', '__pycache__', '.venv'}

def candidates():
    for folder, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in EXCLUDED]
        for name in files:
            p = Path(folder) / name
            if p.is_symlink():
                continue
            rel = p.relative_to(ROOT).as_posix()
            suffix = p.suffix.lower()
            # Authoring references and texture/source inputs are never test output.
            if any(part.lower() in {'references', 'textures', 'source'} for part in p.parts) or 'reference_' in name.lower():
                continue
            preview = (rel.startswith('WorkingAssets/NPCs/') and
                       re.fullmatch(r'(?:.*_)?(?:front|profile|side|back|three_quarter|relaxed|face)\.png', name))
            horse = rel.startswith('WorkingAssets/Horse/candidates/') and name in {'side_review.png', 'game_side_zero.png', 'game_side_pi.png'}
            if (suffix in VIDEO or
                (rel.startswith('docs/') and suffix in MEDIA) or
                (rel.startswith('environment/forest/review/') and suffix in MEDIA) or
                preview or horse or
                (rel.startswith('docs/') and suffix == '.json' and 'validation' in name)):
                yield p


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    targets = sorted(candidates())
    # Only input references count as dependencies. Writers in tools and historical
    # documentation do not make a capture an asset. Godot import sidecars are output.
    runtime = []
    for folder, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in EXCLUDED]
        for name in files:
            p = Path(folder) / name
            rel = p.relative_to(ROOT).as_posix()
            if rel.startswith(('docs/', 'tools/', 'WorkingAssets/')):
                continue
            if p.suffix in {'.gd', '.tscn', '.tres', '.godot', '.gdshader', '.cfg'}:
                runtime.append((rel, p.read_text(errors='replace')))
    deleted = []; skipped = []; total = 0
    for p in targets:
        rel = p.relative_to(ROOT).as_posix()
        refs = [name for name, data in runtime if rel in data]
        if refs:
            skipped.append((rel, refs))
            continue
        companions = [p, Path(str(p) + '.import')]
        for item in companions:
            if item.exists():
                total += item.stat().st_size
                deleted.append(item.relative_to(ROOT).as_posix())
                if args.apply:
                    item.unlink()
    print(('Removed' if args.apply else 'Would remove'), len(deleted), 'files;', total, 'bytes')
    for rel, refs in skipped:
        print('Retained runtime input:', rel, refs)
    if not args.apply:
        for rel in deleted:
            print(rel)

if __name__ == '__main__':
    main()
