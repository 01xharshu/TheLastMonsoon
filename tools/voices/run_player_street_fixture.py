#!/usr/bin/env python3
"""Isolated voice-turn fixture; temporary test project and imports are deleted."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'


def key(speaker, text):
    return hashlib.sha256((speaker + '\n' + text).encode()).hexdigest() + '.wav'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--temporary-samples', action='store_true',
                        help='Use existing speech to test sequencing before final clips exist.')
    parser.add_argument('--real-passing', action='store_true',
                        help='Use real passing recordings with temporary samples for other lines.')
    parser.add_argument('--real-worker', action='store_true',
                        help='Use real worker recordings with temporary samples for other lines.')
    parser.add_argument('--test-mary', action='store_true', help='Stage a complete temporary Mary set to exercise the switch.')
    parser.add_argument('--real-flirt', action='store_true', help='Use the first real Mary and Arjun playful pair.')
    parser.add_argument('--natural-timing', action='store_true', help='Wait for actual first-pair playback and finished signals.')
    parser.add_argument('--real-extended', action='store_true', help='Use all four actual WAVs for the first longer exchange.')
    parser.add_argument('--test-choices', action='store_true', help='Stage a temporary busy-response WAV for choice tests.')
    parser.add_argument('--real-choices', action='store_true', help='Use the actual busy and departure recordings.')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='tlm-voice-fixture-') as folder:
        project = Path(folder)
        for directory in ('world/suryagarh', 'tools/voices', 'assets/audio/dialogue', 'story'):
            (project / directory).mkdir(parents=True)
        (project / 'project.godot').write_text('[application]\nconfig/name="Voice Fixture"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for path in ('world/suryagarh/player_street_conversation.gd', 'tools/voices/validate_player_street_conversation.gd', 'story/dialogue_expression.gd'):
            shutil.copy2(ROOT / path, project / path)
        samples = {'male': key('Indian male', 'Good morning.'),
                   'female': key('Indian female', 'Good morning.'),
                   'arjun': key('Arjun', 'Then let me speak to your superior.')}
        for index in (0, 1):
            for gender in ('male', 'male_alt', 'female', 'female_alt'):
                for kind in ('hello', 'farewell', 'collision', 'assault'):
                    filename = f'context_{gender}_{kind}_{index}.wav'
                    source = samples['female' if gender.startswith('female') else 'male'] if args.temporary_samples else filename
                    shutil.copy2(ROOT / 'assets/audio/dialogue' / source, project / 'assets/audio/dialogue' / filename)
            for gender in ('male', 'male_alt', 'female', 'female_alt'):
                filename = f'context_pass_{gender}_{index}.wav'
                source = samples['female' if gender.startswith('female') else 'male'] if args.temporary_samples and not args.real_passing else filename
                shutil.copy2(ROOT / 'assets/audio/dialogue' / source, project / 'assets/audio/dialogue' / filename)
            for gender in ('male', 'male_alt', 'female', 'female_alt'):
                filename = f'context_worker_{gender}_{index}.wav'
                source = samples['female' if gender.startswith('female') else 'male'] if args.temporary_samples and not args.real_worker else filename
                shutil.copy2(ROOT / 'assets/audio/dialogue' / source, project / 'assets/audio/dialogue' / filename)
            for kind in ('reply', 'goodbye', 'collision', 'assault', 'shop'):
                filename = f'context_arjun_{kind}_{index}.wav'
                source = samples['arjun'] if args.temporary_samples else filename
                shutil.copy2(ROOT / 'assets/audio/dialogue' / source, project / 'assets/audio/dialogue' / filename)
            for gender in ('male', 'male_alt', 'female', 'female_alt'):
                for turn in ('question', 'answer'):
                    filename = f'context_peer_{gender}_{index}_{turn}.wav'
                    source = samples['female' if gender.startswith('female') else 'male'] if args.temporary_samples else filename
                    shutil.copy2(ROOT / 'assets/audio/dialogue' / source, project / 'assets/audio/dialogue' / filename)
            for name in (f'context_police_collision_{index}.wav', f'context_police_assault_{index}.wav', f'context_shop_hello_{index}.wav'):
                source = samples['male'] if args.temporary_samples else name
                shutil.copy2(ROOT / 'assets/audio/dialogue' / source, project / 'assets/audio/dialogue' / name)
        if args.test_mary:
            for index in (0, 1):
                source = f'context_mary_depart_{index}.wav' if args.real_choices else samples['female']
                shutil.copy2(ROOT / 'assets/audio/dialogue' / source,
                             project / 'assets/audio/dialogue' / f'context_mary_depart_{index}.wav')
            for index in (1, 2, 3, 4):
                for part, sample in ((f'mary_flirt_{index}', samples['female']), (f'arjun_mary_flirt_{index}', samples['arjun']), (f'mary_flirt_followup_{index}', samples['female']), (f'arjun_mary_flirt_close_{index}', samples['arjun'])):
                    source = f'context_{part}.wav' if index == 1 and (args.real_extended or (args.real_flirt and 'followup' not in part and 'close' not in part)) else sample
                    shutil.copy2(ROOT / 'assets/audio/dialogue' / source,
                                 project / 'assets/audio/dialogue' / f'context_{part}.wav')
            for index in (0, 1):
                for part in ([f'female_{kind}_{index}' for kind in ('hello', 'farewell', 'collision', 'assault')]
                             + [f'pass_female_{index}', f'worker_female_{index}']
                             + [f'peer_female_{index}_{turn}' for turn in ('question', 'answer')]):
                    shutil.copy2(ROOT / 'assets/audio/dialogue' / samples['female'],
                                 project / 'assets/audio/dialogue' / f'context_mary_{part}.wav')
        if args.test_choices:
            source = 'context_arjun_choice_busy.wav' if args.real_choices else samples['arjun']
            shutil.copy2(ROOT / 'assets/audio/dialogue' / source,
                         project / 'assets/audio/dialogue/context_arjun_choice_busy.wav')
            (project / 'choice_test_enabled').write_text('1')
        if args.test_mary:
            (project / 'mary_test_enabled').write_text('1')
        if args.natural_timing:
            (project / 'natural_timing_enabled').write_text('1')
        for command in ([GODOT, '--headless', '--editor', '--path', str(project), '--import'],
                        [GODOT, '--headless', '--path', str(project), '--script', 'res://tools/voices/validate_player_street_conversation.gd']):
            result = subprocess.run(command, capture_output=True, text=True, timeout=180)
            output = result.stdout + result.stderr
            if 'PLAYER STREET CONVERSATION' in output or result.returncode or 'SCRIPT ERROR:' in output:
                print(output[-6000:] if result.returncode or "ERROR:" in output else output, flush=True)
            if result.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output:
                return 1
        return 0


if __name__ == '__main__':
    raise SystemExit(main())
