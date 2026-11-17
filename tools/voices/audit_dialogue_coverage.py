#!/usr/bin/env python3
"""Audit the explicitly authored voice-generation manifest, not all game scenes."""
from pathlib import Path
import importlib.util
import hashlib
import re

ROOT = Path(__file__).resolve().parents[2]
source = ROOT / 'tools/voices/generate_errand_voices.py'
spec = importlib.util.spec_from_file_location('dialogue_manifest', source)
manifest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manifest)
expected = list(manifest.LINES)
expected.extend((manifest.lesson_key(text), 'Ravi', text) for text in manifest.LESSONS)
expected.extend(item for item in manifest.context_pairs() if not item[0].startswith('audition_'))
missing = []
unimported = []
stale = []
for name, _, _ in expected:
    wav = manifest.OUTPUT / (name + '.wav')
    if not wav.is_file():
        missing.append(name)
    elif not wav.with_name(wav.name + '.import').is_file():
        unimported.append(name)
    else:
        remap = wav.with_name(wav.name + '.import').read_text()
        path_match = re.search(r'^path="res://([^"\n]+)"', remap, re.MULTILINE)
        if not path_match:
            stale.append(name)
            continue
        output = ROOT / path_match.group(1)
        checksum = output.with_suffix('.md5')
        if not output.is_file() or not checksum.is_file():
            stale.append(name)
            continue
        match = re.search(r'^source_md5="([0-9a-f]+)"', checksum.read_text(), re.MULTILINE)
        if not match or hashlib.md5(wav.read_bytes()).hexdigest() != match.group(1):
            stale.append(name)
print(f'AUTHORED DIALOGUE MANIFEST: {len(expected) - len(missing)}/{len(expected)} WAVs; {len(unimported)} await import; {len(stale)} stale imports')
if missing:
    print('MISSING:', ', '.join(missing))
if unimported:
    print('UNIMPORTED:', ', '.join(unimported))
if stale:
    print('STALE:', ', '.join(stale))
raise SystemExit(1 if missing or unimported or stale else 0)
