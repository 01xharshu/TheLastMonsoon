#!/usr/bin/env python3
"""Run the installed contextual voice check with disposable project and saves."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
from dialogue_contract import mary_required

ROOT = Path(__file__).resolve().parents[2]
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sample-audio', action='store_true',
                        help='Use existing recordings to check behavior before final WAVs exist.')
    parser.add_argument('--real-passing', action='store_true',
                        help='Use production passing WAVs with samples for other dialogue.')
    parser.add_argument('--real-worker', action='store_true',
                        help='Use production worker WAVs with samples for other dialogue.')
    parser.add_argument('--flirt-test', action='store_true', help='Exercise a real adult resident with the first real playful WAV pair.')
    parser.add_argument('--production-mary', action='store_true', help='Import real Mary WAVs in a disposable overlay and test normal activation.')
    parser.add_argument('--native', action='store_true', help='Run the populated fixture with the native Metal renderer.')
    parser.add_argument('--real-reactions', action='store_true', help='Use production collision/assault variant-zero WAVs.')
    parser.add_argument('--real-shop', action='store_true', help='Use the imported first merchant/Arjun WAV pair.')
    parser.add_argument('--real-peer', action='store_true', help='Use real first peer WAV pairs and allow natural playback.')
    parser.add_argument('--first-extended', action='store_true', help='Validate first complete extended Mary pair while others generate.')
    parser.add_argument('--real-choices', action='store_true', help='Exercise the production choice/busy/departure WAVs.')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='tlm-context-world-') as folder:
        project = Path(folder) / 'project'
        project.mkdir()
        for item in ROOT.iterdir():
            if item.name not in ('.git', 'project.godot', 'player') and not (args.production_mary and item.name in ('assets', '.godot')):
                (project / item.name).symlink_to(item, target_is_directory=item.is_dir())
        if args.production_mary:
            # Import only new dialogue in a tiny private project, then overlay its
            # remaps on the existing read-only world cache. Never mutate .godot.
            mini = Path(folder) / 'audio_import'
            dialogue = Path('assets/audio/dialogue')
            (mini / dialogue).mkdir(parents=True)
            (mini / 'project.godot').write_text('[application]\nconfig/name="Voice import"\n')
            names = list((ROOT / dialogue).glob('context_mary_*.wav')) + list((ROOT / dialogue).glob('context_arjun_mary_flirt_*.wav')) + list((ROOT / dialogue).glob('context_arjun_reply_*.wav'))
            missing = [name for name in mary_required(first_extended=args.first_extended) if not (ROOT / dialogue / name).is_file()]
            if missing:
                raise SystemExit('Mary production recording set is incomplete: ' + ', '.join(missing))
            for source in names:
                shutil.copy2(source, mini / dialogue / source.name)
            imported = subprocess.run([GODOT, '--headless', '--editor', '--path', str(mini), '--import'], capture_output=True, text=True, timeout=180)
            if imported.returncode or 'SCRIPT ERROR:' in imported.stderr:
                print(imported.stdout + imported.stderr, flush=True)
                return 1
            for directory in (Path('assets'), Path('assets/audio')):
                (project / directory).mkdir(exist_ok=True)
                for item in (ROOT / directory).iterdir():
                    if (directory == Path('assets') and item.name == 'audio') or (directory == Path('assets/audio') and item.name == 'dialogue'):
                        continue
                    (project / directory / item.name).symlink_to(item, target_is_directory=item.is_dir())
            dest = project / dialogue
            dest.mkdir()
            replacing = {p.name for p in names}
            for item in (ROOT / dialogue).iterdir():
                if item.name in replacing or item.name.removesuffix('.import') in replacing:
                    continue
                (dest / item.name).symlink_to(item, target_is_directory=item.is_dir())
            for item in (mini / dialogue).iterdir():
                shutil.copy2(item, dest / item.name)
            cache = project / '.godot'
            cache.mkdir()
            for item in (ROOT / '.godot').iterdir():
                if item.name != 'imported':
                    (cache / item.name).symlink_to(item, target_is_directory=item.is_dir())
            (cache / 'imported').mkdir()
            for item in (ROOT / '.godot/imported').iterdir():
                (cache / 'imported' / item.name).symlink_to(item)
            for item in (mini / '.godot/imported').iterdir():
                dest_import = cache / 'imported' / item.name
                if dest_import.is_symlink():
                    dest_import.unlink()
                shutil.copy2(item, dest_import)
        player = project / 'player'
        player.mkdir()
        for item in (ROOT / 'player').iterdir():
            if item.name == 'arjun_carry_motion.gd':
                raw = item.read_text()
                (player / item.name).write_text('\n'.join(
                    line[:len(line) - len(line.lstrip())].expandtabs(4) + line.lstrip()
                    for line in raw.split('\n')))
            else:
                (player / item.name).symlink_to(item, target_is_directory=item.is_dir())
        config = (ROOT / 'project.godot').read_text().replace(
            '[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + Path(folder).name + '"', 1)
        (project / 'project.godot').write_text(config)
        env = os.environ.copy()
        env['TLM_SAVE_TEST_DIR'] = folder
        env['TLM_CONTEXT_SAMPLE_AUDIO'] = '1' if args.sample_audio else '0'
        env['TLM_CONTEXT_REAL_PASSING'] = '1' if args.real_passing else '0'
        env['TLM_CONTEXT_REAL_WORKER'] = '1' if args.real_worker else '0'
        env['TLM_CONTEXT_FLIRT_TEST'] = '1' if args.flirt_test else '0'
        env['TLM_CONTEXT_PRODUCTION_MARY'] = '1' if args.production_mary else '0'
        env['TLM_CONTEXT_REAL_REACTIONS'] = '1' if args.real_reactions else '0'
        env['TLM_CONTEXT_REAL_SHOP'] = '1' if args.real_shop else '0'
        env['TLM_CONTEXT_REAL_PEER'] = '1' if args.real_peer else '0'
        env['TLM_CONTEXT_FIRST_EXTENDED'] = '1' if args.first_extended else '0'
        env['TLM_CONTEXT_REAL_CHOICES'] = '1' if args.real_choices else '0'
        try:
            display = ['--rendering-driver', 'metal', '--resolution', '960x540'] if args.native else ['--headless']
            result = subprocess.run([GODOT, *display, '--path', str(project), '--script',
                                     'res://tools/voices/validate_player_street_world.gd'],
                                    env=env, timeout=480)
            print('PLAYER STREET WORLD EXIT', result.returncode, flush=True)
            return result.returncode
        finally:
            shutil.rmtree(Path.home() / 'Library/Application Support' / Path(folder).name, ignore_errors=True)


if __name__ == '__main__':
    raise SystemExit(main())
