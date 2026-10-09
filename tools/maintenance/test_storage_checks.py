"""Reusable storage/integration guard tests; all fixtures live in OS temp."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
import check_push_sizes as check
import install_storage_hooks as installer


class StorageChecks(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='tlm-storage-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Storage test')
        self.git('config', 'user.email', 'storage-test@example.invalid')
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(patch.object(check, 'ROOT', self.root))
        self.stack.enter_context(patch.object(check, 'LIMIT', 4096))
        self.stack.enter_context(patch.object(installer, 'ROOT', self.root))

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, stderr=subprocess.DEVNULL)

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)

    def stage(self):
        self.git('add', '-A')

    def blobs(self):
        return [(row.split(b'\t')[0].split()[1], row.split(b'\t')[1])
                for row in self.git('ls-files', '--stage', '-z').split(b'\0') if row]

    def test_oversized_asset_any_extension(self):
        self.write('source/character.blend', b'x' * 5000)
        self.stage()
        self.assertTrue(check.check_blobs(self.blobs()))

    def test_removed_oversized_file_still_blocks_outgoing_history(self):
        self.write('asset.res', b'x' * 5000)
        self.stage()
        self.git('commit', '-qm', 'large')
        (self.root / 'asset.res').unlink()
        self.write('README.md', b'replacement')
        self.stage()
        self.git('commit', '-qm', 'removed')
        self.assertFalse(check.check_blobs(self.blobs()))
        self.assertTrue(check.check_blobs(check.history_blobs(['HEAD'])))

    def test_lfs_pointer_without_attributes_is_rejected(self):
        self.write('asset.glb', b'version https://git-lfs.github.com/spec/v1\n'
                   b'oid sha256:' + b'0' * 64 + b'\nsize 123\n')
        self.stage()
        self.assertTrue(check.check_blobs(self.blobs()))

    def test_lfs_attributes_are_rejected(self):
        self.write('.gitattributes', b'*.glb filter=lfs\n')
        self.write('asset.glb', b'real asset')
        self.assertTrue(check.check_lfs_attributes([b'asset.glb']))

    def test_local_unstaged_dependency_does_not_pass(self):
        self.write('player.gd', b'extends Node\nvar model = preload("res://models/player.glb")\n')
        self.git('add', 'player.gd')
        self.write('models/player.glb', b'real asset')
        self.assertTrue(check.check_runtime_dependencies(self.blobs()))
        self.stage()
        self.assertFalse(check.check_runtime_dependencies(self.blobs()))

    def test_push_excludes_existing_remote_history_and_handles_deletion(self):
        self.write('asset.res', b'x' * 5000)
        self.stage()
        self.git('commit', '-qm', 'remote baseline')
        oid = self.git('rev-parse', 'HEAD').decode().strip()
        update = f'refs/heads/main {oid} refs/heads/main {oid}\n'
        self.assertFalse(check.pre_push_blobs('origin', [update]))
        new_branch = f'refs/heads/main {oid} refs/heads/new {"0" * 40}\n'
        self.assertTrue(check.check_blobs(check.pre_push_blobs('origin', [new_branch])))
        deletion = f'(delete) {"0" * 40} refs/heads/main {oid}\n'
        self.assertFalse(check.pre_push_blobs('origin', [deletion]))

    def test_hook_installer_is_repeatable_and_preserves_custom_hooks(self):
        with contextlib.redirect_stdout(io.StringIO()):
            installer.main()
            installer.main()
        hook = self.root / '.git/hooks/pre-push'
        self.assertIn('--pre-push', hook.read_text())
        hook.write_text('#!/bin/sh\n# custom hook\nexit 0\n')
        with self.assertRaises(SystemExit):
            installer.main()
        self.assertIn('# custom hook', hook.read_text())

    def test_new_uvless_morph_export_requires_safe_import_settings(self):
        header = json.dumps({'meshes': [{'primitives': [{'attributes': {'NORMAL': 0},
                                                        'targets': [{'NORMAL': 1}]}]}]}).encode()
        self.write('characters/cloth.glb', b'glTF' + struct.pack('<IIII', 2, len(header) + 20,
                                                             len(header), 0x4E4F534A) + header)
        self.stage()
        self.assertTrue(check.check_changed_glb_imports(self.blobs()))
        self.write('characters/cloth.glb.import', b'[params]\nmeshes/ensure_tangents=false\n')
        self.write('project.godot', b'[editor_plugins]\nenabled=PackedStringArray("res://addons/safe_mesh_tangents/plugin.cfg")\n')
        self.stage()
        self.assertFalse(check.check_changed_glb_imports(self.blobs()))


if __name__ == '__main__':
    unittest.main()
