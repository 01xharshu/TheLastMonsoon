"""Restore the exact licensed inputs recorded in docs/world/asset_manifest.json."""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]

def fetch(record):
    target = (ROOT / record['path']).resolve()
    if not target.is_relative_to(ROOT):
        raise ValueError('Asset path escapes repository')
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == record['sha256']:
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(target.suffix + '.download')
    subprocess.run(['curl', '-sSfL', '--retry', '2', '-A', 'TheLastMonsoon/0.1',
                    record['source'], '-o', str(temporary)], check=True)
    if hashlib.sha256(temporary.read_bytes()).hexdigest() != record['sha256']:
        temporary.unlink(missing_ok=True)
        raise RuntimeError('Asset checksum mismatch: ' + record['path'])
    temporary.replace(target)

if __name__ == '__main__':
    manifest = json.loads((ROOT / 'docs/world/asset_manifest.json').read_text())
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        list(executor.map(fetch, manifest))
    print(f'ASSET CHECKSUMS PASS: {len(manifest)} files')
