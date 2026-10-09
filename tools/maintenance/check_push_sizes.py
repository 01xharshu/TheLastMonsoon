"""Check GitHub's regular Git blob limit without creating reports or staging files.

Default: all tracked and non-ignored working files. --index: staged snapshot.
Required large assets must be compressed or split; never ignore them to pass.
This repository uses regular Git to avoid a paid asset-storage dependency.
"""
import argparse
from pathlib import Path
import re
import json
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
LIMIT = 100 * 1024 * 1024


def git(*args, data=None):
    return subprocess.check_output(['git', *args], cwd=ROOT, input=data)


def check_blobs(blobs):
    failures = []
    if not blobs:
        return failures
    rows = git('cat-file', '--batch-check=%(objecttype) %(objectsize)',
               data=b''.join(oid + b'\n' for oid, _ in blobs)).splitlines()
    small = []
    for (oid, path), row in zip(blobs, rows):
        kind, size = row.split()
        if kind != b'blob':
            continue
        size = int(size)
        name = path.decode(errors='replace')
        if size >= LIMIT:
            failures.append(name + ': oversized Git blob; compress or split before committing')
        elif size <= 1024:
            small.append((oid, name))
    # Reject LFS pointers even without attributes: a clone must contain the asset.
    if small:
        content = git('cat-file', '--batch', data=b''.join(oid + b'\n' for oid, _ in small))
        offset = 0
        for _, name in small:
            end = content.index(b'\n', offset)
            size = int(content[offset:end].split()[2])
            offset = end + 1
            body = content[offset:offset + size]
            offset += size + 1
            if body.startswith(b'version https://git-lfs.github.com/spec/v1\n'):
                failures.append(name + ': LFS pointer violates regular-Git storage policy')
    return failures


def history_blobs(revisions):
    blobs = []
    for row in git('rev-list', '--objects', *revisions).splitlines():
        oid, _, path = row.partition(b' ')
        blobs.append((oid, path or oid))
    return blobs


def pre_push_blobs(remote, lines):
    revisions = []
    exclusions = []
    for line in lines:
        _, local_oid, _, remote_oid = line.split()
        if set(local_oid) == {'0'}:
            continue
        revisions.append(local_oid)
        if set(remote_oid) != {'0'} and subprocess.run(
                ['git', 'cat-file', '-e', remote_oid], cwd=ROOT,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            exclusions.append(remote_oid)
    if not revisions:
        return []
    # New branches exclude objects already on this remote. URL-only remotes can
    # conservatively check all local ancestry when no tracking refs exist.
    exclusions.extend(git('for-each-ref', '--format=%(objectname)',
                          'refs/remotes/' + remote + '/').decode().splitlines())
    return history_blobs(revisions + (['--not', *exclusions] if exclusions else []))


def check_lfs_attributes(paths, cached=False):
    if not paths:
        return []
    flags = ['--cached'] if cached else []
    rows = git('check-attr', *flags, '-z', '--stdin', 'filter',
               data=b'\0'.join(paths) + b'\0').split(b'\0')
    return [rows[i].decode(errors='replace') + ': remove LFS tracking'
            for i in range(0, len(rows) - 1, 3) if rows[i + 2] == b'lfs']


def check_runtime_dependencies(blobs):
    """Catch runtime files that exist locally but would be missing from a clone.

    Only complete literal res:// paths are checked. Dynamic paths, rendering,
    exported-pack availability and gameplay still require Godot verification.
    """
    paths = {path.decode(errors='surrogateescape') for _, path in blobs}
    sources = [(oid, path) for oid, path in blobs
               if Path(path.decode(errors='surrogateescape')).suffix in
               {'.gd', '.tscn', '.tres', '.import', '.godot', '.gdshader'}
               and not path.startswith((b'tools/', b'docs/', b'WorkingAssets/', b'website/'))]
    if not sources:
        return []
    content = git('cat-file', '--batch', data=b''.join(oid + b'\n' for oid, _ in sources))
    offset = 0
    failures = set()
    for _, path in sources:
        end = content.index(b'\n', offset)
        size = int(content[offset:end].split()[2])
        offset = end + 1
        body = content[offset:offset + size].decode(errors='replace')
        offset += size + 1
        for target in re.findall(r'''["']res://([^"'\r\n]+)["']''', body):
            target = target.split('::')[0]
            if target.startswith('.godot/') or any(char in target for char in '*%{'):
                continue
            if not Path(target).suffix or target.endswith('/'):
                continue
            if target not in paths:
                failures.add(path.decode(errors='replace') + ': missing staged runtime dependency ' + target)
    return sorted(failures)


def check_changed_glb_imports(blobs):
    paths = {path.decode(errors='surrogateescape') for _, path in blobs}
    changed = git('diff', '--cached', '--name-only', '--diff-filter=ACMR', '-z').decode(errors='surrogateescape').split('\0')
    targets = {path[:-7] if path.endswith('.glb.import') else path
               for path in changed if path.endswith(('.glb', '.glb.import'))}
    failures = []
    for target in sorted(targets):
        if target not in paths or target.startswith(('WorkingAssets/', 'docs/', 'tools/', 'website/')):
            continue
        data = git('show', ':' + target)
        if not data.startswith(b'glTF'):
            continue  # Pointer checks above report LFS; Godot validates other formats.
        try:
            length, kind = struct.unpack_from('<II', data, 12)
            if kind != 0x4E4F534A or length > len(data) - 20:
                raise ValueError('invalid JSON chunk')
            model = json.loads(data[20:20 + length])
        except (ValueError, struct.error):
            failures.append(target + ': invalid GLB header')
            continue
        needs_safe_import = any(
            primitive.get('mode', 4) == 4 and primitive.get('targets') and
            'NORMAL' in primitive.get('attributes', {}) and
            'TANGENT' not in primitive['attributes'] and 'TEXCOORD_0' not in primitive['attributes']
            for mesh in model.get('meshes', []) for primitive in mesh.get('primitives', []))
        if not needs_safe_import:
            continue
        sidecar = target + '.import'
        settings = git('show', ':' + sidecar).decode() if sidecar in paths else ''
        if not re.search(r'^meshes/ensure_tangents=false\s*$', settings, re.MULTILINE):
            failures.append(target + ': UV-less morphs require tracked safe tangent import settings')
        config = git('show', ':project.godot').decode() if 'project.godot' in paths else ''
        plugins = re.search(r'\[editor_plugins\](.*?)(?:\n\[|\Z)', config, re.DOTALL)
        if plugins is None or 'res://addons/safe_mesh_tangents/plugin.cfg' not in plugins.group(1):
            failures.append(target + ': safe tangent importer must be enabled in project.godot')
    return failures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--index', action='store_true')
    group.add_argument('--history', nargs='+', metavar='REF')
    group.add_argument('--pre-push', metavar='REMOTE', help='Read Git pre-push ref updates from stdin')
    args = parser.parse_args()
    failures = []
    label = 'commit-eligible working files'
    if args.history:
        failures.extend(check_blobs(history_blobs(args.history)))
        label = 'reachable Git history'
    elif args.pre_push is not None:
        failures.extend(check_blobs(pre_push_blobs(args.pre_push, sys.stdin)))
        label = 'outgoing Git history'
    elif args.index:
        label = 'staged Git blobs'
        entries = git('ls-files', '--stage', '-z').split(b'\0')
        blobs = []
        for entry in filter(None, entries):
            meta, path = entry.split(b'\t', 1)
            mode, oid, stage = meta.split()
            if stage != b'0':
                failures.append('Unmerged: ' + path.decode(errors='replace'))
            elif mode != b'160000':
                blobs.append((oid, path))
        failures.extend(check_blobs(blobs))
        failures.extend(check_lfs_attributes([path for _, path in blobs], cached=True))
        failures.extend(check_runtime_dependencies(blobs))
        failures.extend(check_changed_glb_imports(blobs))
    else:
        paths = set(filter(None, git('ls-files', '-c', '-o', '--exclude-standard', '-z').split(b'\0')))
        large = []
        for raw in paths:
            path = ROOT / raw.decode(errors='surrogateescape')
            if path.is_file() and not path.is_symlink() and path.stat().st_size >= LIMIT:
                large.append(raw)
        for path in large:
            failures.append(path.decode(errors='replace') + ': compress or split before staging')
        failures.extend(check_lfs_attributes(sorted(paths)))
        for raw in paths:
            path = ROOT / raw.decode(errors='surrogateescape')
            if path.is_file() and not path.is_symlink() and path.stat().st_size <= 1024:
                if path.read_bytes().startswith(b'version https://git-lfs.github.com/spec/v1\n'):
                    failures.append(raw.decode(errors='replace') + ': LFS pointer instead of asset')
    for failure in failures:
        print('FAIL:', failure)
    print(('FAIL' if failures else 'PASS') + ': ' + label + ' size/LFS check')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
