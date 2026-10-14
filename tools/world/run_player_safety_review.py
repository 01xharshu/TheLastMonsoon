#!/usr/bin/env python3
"""Review production rider/river motion; discard all media and logs on exit."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import time
from run_performance_checks import other_native_jobs

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--no-captures', action='store_true', help='Observe playback without screenshot/readback overhead')
    parser.add_argument('--pouch-source-pixels', action='store_true', help='Compare cached/reference pouch preparation and pixels')
    parser.add_argument('--reference-pouch', action='store_true', help='Use the original source readbacks for comparison')
    parser.add_argument('--case', choices=['horse','open_cart','carriage_left','carriage_right'])
    parser.add_argument('--hold', action='store_true', help='Keep temporary captures until Enter for inspection')
    args = parser.parse_args()
    if not args.headless:
        deadline = time.monotonic()+240
        announced = False
        while other_native_jobs():
            if not announced:
                print('Waiting for the existing renderer; other work will remain running.', flush=True)
                announced = True
            if time.monotonic() >= deadline:
                print('Renderer is still occupied; review was not launched.', flush=True)
                return 2
            time.sleep(3)
    with tempfile.TemporaryDirectory(prefix='tlm-river-motion-') as output:
        command = [os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot'),
                   '--path', str(ROOT), '--log-file', output+'/engine.log',
                   '--script', 'res://tools/characters/validate_water_bag_source_pixels.gd' if args.pouch_source_pixels else 'res://tools/world/review_player_river_escape.gd', '--', '--output='+output]
        if args.no_captures:
            command.append("--no-captures")
        if args.reference_pouch:
            command.append("--water-bag-source-reference")
        if args.case:
            command.append("--case="+args.case)
        if args.headless:
            command.insert(1, '--headless')
        print(output, flush=True)
        process = subprocess.Popen(command)
        try:
            deadline = time.monotonic()+180
            while process.poll() is None:
                if not args.headless and other_native_jobs(process.pid):
                    print('Another renderer started; stopping only this review and discarding its output.', flush=True)
                    return 2
                if time.monotonic() >= deadline:
                    raise subprocess.TimeoutExpired(command,180)
                try:
                    process.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    pass
            status = process.returncode
            if args.hold:
                input()
            return status
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()

if __name__ == '__main__':
    raise SystemExit(main())
