#!/usr/bin/env python3
"""Run production errand callouts with disposable Godot imports."""
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'
with tempfile.TemporaryDirectory(prefix='tlm-errand-voices-') as folder:
    project = Path(folder)
    (project / 'project.godot').write_text('[application]\nconfig/name="Errand voice fixture"\n')
    for name in ('world/suryagarh/errands/expanded_jobs.gd', 'tools/voices/validate_errand_callouts.gd', 'world/suryagarh/errands/passenger_contact.gd'):
        dest = project / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / name, dest)
    for name in ('vehicles/horse_cart_candidate.gd', 'world/suryagarh/settlements/household_resident_journey.gd'):
        dest = project / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text('extends Node3D\n')
    for source in (ROOT / 'assets/audio/dialogue').glob('errand_*.wav'):
        dest = project / 'assets/audio/dialogue' / source.name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)
    for command in ([GODOT, '--headless', '--editor', '--path', str(project), '--import'],
                    [GODOT, '--headless', '--path', str(project), '--script', 'res://tools/voices/validate_errand_callouts.gd']):
        result = subprocess.run(command, capture_output=True, text=True, timeout=180)
        output = result.stdout + result.stderr
        if result.returncode or 'ERROR:' in output or 'ERRAND CALLOUTS' in output:
            print(output, flush=True)
        if result.returncode or 'ERROR:' in output:
            raise SystemExit(1)
