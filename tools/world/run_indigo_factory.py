"""Verify factory in an isolated current-source project, deleting all test output."""
import argparse
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'maintenance'))
import check_game

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cached', action='store_true')
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--architecture', action='store_true', help='Factory-only construction review; does not replace New Journey/Continue verification.')
    parser.add_argument('--continue', dest='continue_game', action='store_true')
    parser.add_argument('--inspect', action='store_true')
    parser.add_argument('--reference', action='store_true', help='Smoke the same copied world without the factory or its reservations; source checkout is untouched.')
    args = parser.parse_args()
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    with tempfile.TemporaryDirectory(prefix='tlm-factory-') as folder:
        directory = Path(folder)
        project = directory / 'project'
        try:
            shutil.copytree(check_game.ROOT, project, copy_function=check_game.copy_stable_file,
                            ignore=shutil.ignore_patterns('.git', '.godot', 'WorkingAssets', '__pycache__', 'node_modules', '.next'))
            config = project / 'project.godot'
            config.write_text(config.read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + directory.name + '"'))
            if args.cached:
                cache = project / '.godot'; cache.mkdir()
                shutil.copytree(check_game.ROOT / '.godot/imported', cache / 'imported', copy_function=check_game.copy_stable_file)
                for name in ('global_script_class_cache.cfg', 'uid_cache.bin'):
                    shutil.copy2(check_game.ROOT / '.godot' / name, cache / name)
                print('Copied imports; fresh import not verified.', flush=True)
            binary = '/Applications/Godot.app/Contents/MacOS/Godot'
            if args.reference:
                for relative, line in [
                    ('world/suryagarh/suryagarh_world.gd', '\tadd_child(preload("res://world/suryagarh/settlements/indigo_factory.gd").new())\n'),
                    ('world/suryagarh/landscape_layout.gd', '\tif preload("res://world/suryagarh/settlements/indigo_factory_data.gd").reserved(Vector2(x,z)):return 0.0\n'),
                    ('world/suryagarh/tree_trunk_collision.gd', '\tif preload("res://world/suryagarh/settlements/indigo_factory_data.gd").reserved(point,2.0):return true\n')]:
                    file = project / relative
                    source = file.read_text()
                    assert source.count(line) == 1, relative + ': factory integration line changed'
                    file.write_text(source.replace(line, ''))
            if not check_game.run_check(binary, project, directory, 'FACTORY_CODE', ['--script', 'res://tools/maintenance/validate_code.gd'], 180):
                return 1
            if not args.cached and not check_game.run_check(binary, project, directory, 'IMPORT', ['--import'], 600):
                return 1
            os.environ['TLM_FACTORY_ARCHITECTURE'] = '1' if args.architecture else '0'
            os.environ['TLM_FACTORY_CONTINUE'] = '1' if args.continue_game else '0'
            os.environ['TLM_FACTORY_IMAGES'] = folder if args.native else ''
            print('Temporary factory review:', folder, flush=True)
            if args.native:
                started = time.monotonic()
                announced = False
                while True:
                    active = []
                    listing = subprocess.check_output(['ps', '-axo', 'pid=,args='], text=True)
                    for row in listing.splitlines():
                        parts = row.strip().split(maxsplit=1)
                        if len(parts) == 2 and parts[1].startswith(binary + ' ') and '--headless' not in parts[1] and '--editor' not in parts[1]:
                            active.append(parts[0])
                    if not active: break
                    if not announced:
                        print('Waiting for existing native renderer; no other process is interrupted.', flush=True)
                        announced = True
                    if time.monotonic() - started > 600:
                        print('Native renderer remained busy; factory native check not run.', flush=True)
                        return 2
                    time.sleep(5)
            command = ['--fixed-fps', '30', '--script', 'res://tools/world/validate_indigo_factory.gd']
            if args.reference:
                command = ['--fixed-fps', '30', '--script', 'res://tools/maintenance/smoke_game.gd', '--', '--world']
            okay = check_game.run_check(binary, project, directory, 'FACTORY', command, 600, native=args.native)
            for line in (directory / 'FACTORY.log').read_text(errors='replace').splitlines():
                if line.startswith(('INDIGO FACTORY', 'FACTORY NATIVE')): print(line, flush=True)
            if os.environ.get('TLM_FACTORY_DIAGNOSE') == '1':
                lines = (directory / 'FACTORY.log').read_text(errors='replace').splitlines()
                for i, line in enumerate(lines):
                    if line.startswith('ERROR:') or line.startswith('FACTORY GRASS'):
                        print('\n'.join(lines[max(0, i-1):i+2]), flush=True)
            if args.inspect and args.native: input('Inspect temporary views, then Enter to delete: ')
            return 0 if okay else 1
        finally:
            shutil.rmtree(check_game.user_data_directory(directory.name), ignore_errors=True)
            print('Factory test snapshot, views, logs and saves deleted on exit.', flush=True)

if __name__ == '__main__':
    raise SystemExit(main())
