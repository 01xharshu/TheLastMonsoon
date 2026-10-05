"""Conservative evidence retention: remove only exact, unreferenced clean duplicates.
Run normally to audit; --apply removes proven duplicates and their import sidecars.
Distinct views, motion clips, concurrent edits and editable sources remain intact.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[2]
MEDIA = {'.png', '.jpg', '.jpeg', '.webp', '.mp4', '.mov', '.gif'}
tracked = subprocess.check_output(['git', 'status', '--porcelain', '-z'], cwd=ROOT).decode().split('\0')
dirty = {line[3:] for line in tracked if line}
texts = []
for folder in ['docs', 'tools', 'WorkingAssets']:
    for path in (ROOT / folder).rglob('*'):
        if path.is_file() and path.suffix in {'.md', '.json', '.py', '.gd', '.html'}:
            texts.append(path.read_text(errors='replace'))
references = '\n'.join(texts)
groups = {}
media = []
for path in (ROOT / 'docs').rglob('*'):
    if path.is_file() and path.suffix.lower() in MEDIA:
        media.append(path)
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        groups.setdefault(digest, []).append(path)
removed = []
for digest, paths in groups.items():
    if len(paths) < 2: continue
    # Prefer a linked or concurrent artifact as the retained replacement.
    paths.sort(key=lambda p: (p.name not in references, str(p.relative_to(ROOT)) not in dirty, str(p)))
    replacement = paths[0]
    for path in paths[1:]:
        relative = str(path.relative_to(ROOT))
        if relative in dirty or path.name in references: continue
        if relative + '.import' in dirty: continue
        removed.append({'path': relative, 'bytes': path.stat().st_size, 'sha256': digest,
                        'replacement': str(replacement.relative_to(ROOT))})
if '--apply' in sys.argv:
    for item in removed:
        path = ROOT / item['path']
        if hashlib.sha256(path.read_bytes()).hexdigest() != item['sha256']:
            raise RuntimeError('Evidence changed during audit: ' + item['path'])
        path.unlink()
        path.with_name(path.name + '.import').unlink(missing_ok=True)
report = {'status': 'APPLIED' if '--apply' in sys.argv else 'AUDIT',
          'media_count': len(media), 'media_bytes': sum(p.stat().st_size for p in media if p.exists()),
          'reclaimed_bytes': sum(x['bytes'] for x in removed), 'duplicates': removed,
          'policy': 'Keep distinct evidence and active defects; replace same-view captures in place. No age-based deletion.'}
(ROOT / 'docs/assets/workspace_evidence_retention.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k != 'duplicates'}, indent=2))
