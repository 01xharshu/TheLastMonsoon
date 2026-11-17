#!/usr/bin/env python3
"""Import the completed Mary dialogue into Godot without scanning the world.

Imports are produced in a disposable project with identical res:// paths. Only
missing dialogue remaps and their generated cache files are copied into the
active checkout, so existing imports and other editors are never overwritten.
"""
from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile
from dialogue_contract import mary_required

ROOT = Path(__file__).resolve().parents[2]
DIALOGUE = Path('assets/audio/dialogue')
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--all', action='store_true', help='Import every currently generated production dialogue WAV not yet imported.')
args = parser.parse_args()
if args.all:
    names = sorted(p for p in (ROOT / DIALOGUE).glob('*.wav')
                   if not p.name.startswith('audition_') and not p.with_name(p.name + '.import').exists())
    if not names:
        print('DIALOGUE IMPORT: no new WAVs')
        raise SystemExit(0)
else:
    names = sorted((ROOT / DIALOGUE).glob('context_mary_*.wav')) + sorted((ROOT / DIALOGUE).glob('context_arjun_mary_flirt_*.wav')) + sorted((ROOT / DIALOGUE).glob('context_arjun_reply_*.wav'))
    missing = [name for name in mary_required() if not (ROOT / DIALOGUE / name).is_file()]
    if missing:
        raise SystemExit('Mary dialogue set is incomplete: ' + ', '.join(missing))
with tempfile.TemporaryDirectory(prefix='tlm-mary-import-') as folder:
    project = Path(folder)
    (project / DIALOGUE).mkdir(parents=True)
    (project / 'project.godot').write_text('[application]\nconfig/name="Mary voice import"\n')
    for source in names:
        shutil.copy2(source, project / DIALOGUE / source.name)
    result = subprocess.run([GODOT, '--headless', '--editor', '--path', str(project), '--import'],
                            capture_output=True, text=True, timeout=180)
    if result.returncode or 'SCRIPT ERROR:' in result.stderr:
        raise SystemExit(result.stdout + result.stderr)
    cache = ROOT / '.godot/imported'
    cache.mkdir(parents=True, exist_ok=True)
    created = 0
    for item in (project / '.godot/imported').iterdir():
        dest = cache / item.name
        if not dest.exists():
            shutil.copy2(item, dest)
    for source in names:
        generated = project / DIALOGUE / (source.name + '.import')
        target = ROOT / DIALOGUE / generated.name
        if not target.exists():
            shutil.copy2(generated, target)
            created += 1
    print(f'DIALOGUE IMPORT: {len(names)} WAVs, {created} new remaps; existing imports preserved')
