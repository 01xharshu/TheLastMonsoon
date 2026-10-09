"""Check the integrated opening; all captures, audio and logs are disposable."""
from pathlib import Path
import argparse
import math
import json
import os
import signal
import struct
import subprocess
import tempfile
import time
import wave

ROOT = Path(__file__).resolve().parents[2]


def inspect_mix(path):
    with wave.open(str(path)) as recording:
        channels, rate = recording.getnchannels(), recording.getframerate()
        values = struct.unpack('<' + 'h' * recording.getnframes() * channels,
                               recording.readframes(recording.getnframes()))
    peak = max(abs(value) for value in values) / 32768
    print(f'Native mix: {len(values) / channels / rate:.2f}s, peak {peak:.3f}')
    frames = [max(abs(values[i * channels + k]) for k in range(channels)) / 32768
              for i in range(len(values) // channels)]
    passed = peak < .99
    # Score fades in gently, loops under the cards, then dawn wind stays continuous.
    morning = json.loads((path.parent / "timing.json").read_text())["morning"]
    print(f"Measured morning handoff: {morning:.2f}s")
    for start, end in [(0, .15), (4, 8), (22, 26), (morning + 2.0, morning + 11.0)]:
        window = frames[int(start * rate):int(end * rate)]
        stride = int(.02 * rate)
        levels = [math.sqrt(sum(x * x for x in window[i:i + stride]) /
                            len(window[i:i + stride])) for i in range(0, len(window), stride)]
        silent = sum(level < 1e-5 for level in levels)
        if silent and start > 0:
            print("Quiet dawn windows:", [round(start + i * .02, 2) for i, level in enumerate(levels) if level < 1e-5], flush=True)
        print(f'Mix {start}–{end}s: RMS {min(levels):.6f}–{max(levels):.6f}; '
              f'{silent}/{len(levels)} silent 20ms windows')
        passed &= max(levels) < .0001 if start == 0 else silent == 0
        if start == 4:
            passed &= max(levels) > .001
    return passed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--review-seconds', type=int, default=0, help='Hold disposable frames briefly for visual inspection (max 30s)')
    args = parser.parse_args()
    passed = False
    try:
        with tempfile.TemporaryDirectory(prefix='tlm-opening-check-') as tmp:
            print('Disposable review directory: ' + tmp, flush=True)
            command = ['/Applications/Godot.app/Contents/MacOS/Godot', '--path', str(ROOT),
                       '--log-file', tmp + '/godot.log']
            command += ['--headless'] if args.headless else ['--windowed', '--resolution', '1280x720', '--max-fps', '60']
            command += ['--script', 'res://tools/world/validate_opening_integration.gd']
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, start_new_session=True,
                                       env=dict(os.environ, TLM_OPENING_TEST_OUTPUT=tmp))
            try:
                output, _ = process.communicate(timeout=190)
                for line in output.splitlines():
                    if any(label in line for label in ['ERROR', 'WARNING', 'OPENING INTEGRATION']):
                        print(line, flush=True)
                passed = process.returncode == 0 and 'OPENING INTEGRATION: PASS' in output and 'ERROR' not in output
                if passed and not args.headless:
                    passed = inspect_mix(Path(tmp) / 'opening_mix.wav')
                if args.review_seconds:
                    print("Frames available briefly for review: " + tmp, flush=True)
                    time.sleep(max(0, min(30, args.review_seconds)))
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
    finally:
        print('Temporary captures/audio/logs deleted.', flush=True)
    print('OPENING CHECKS: ' + ('PASS' if passed else 'FAIL'), flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
