"""Check GitHub's regular Git blob limit without creating reports or staging files.

Default: all tracked and non-ignored working files. --index: staged snapshot.
Required large assets must be compressed or split; never ignore them to pass.
This repository uses regular Git to avoid a paid asset-storage dependency.
"""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
LIMIT = 100 * 1024 * 1024


def git(*args, data=None):
    return subprocess.check_output(['git', *args], cwd=ROOT, input=data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--index', action='store_true')
    args = parser.parse_args()
    failures = []
    if args.index:
        entries = git('ls-files', '--stage', '-z').split(b'\0')
        blobs = []
        for entry in filter(None, entries):
            meta, path = entry.split(b'\t', 1)
            mode, oid, stage = meta.split()
            if stage != b'0':
                failures.append('Unmerged: ' + path.decode(errors='replace'))
            elif mode != b'160000':
                blobs.append((oid, path))
        sizes = git('cat-file', '--batch-check=%(objectsize)',
                    data=b''.join(oid + b'\n' for oid, _ in blobs)).splitlines()
        for (_, path), size in zip(blobs, sizes):
            if int(size) >= LIMIT:
                failures.append(path.decode(errors='replace') + ': oversized staged Git blob')
    else:
        paths = set(filter(None, git('ls-files', '-c', '-o', '--exclude-standard', '-z').split(b'\0')))
        large = []
        for raw in paths:
            path = ROOT / raw.decode(errors='surrogateescape')
            if path.is_file() and not path.is_symlink() and path.stat().st_size >= LIMIT:
                large.append(raw)
        for path in large:
            failures.append(path.decode(errors='replace') + ': compress or split before staging')
    for failure in failures:
        print('FAIL:', failure)
    print(('FAIL' if failures else 'PASS') + ': ' + ('staged Git blobs' if args.index else 'commit-eligible working files') + ' size check')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
