#!/usr/bin/env python3
"""Review production rider/river motion; discard all media and logs on exit."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--case', choices=['horse','open_cart','carriage_left','carriage_right'])
    parser.add_argument('--hold', action='store_true', help='Keep temporary captures until Enter for inspection')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='tlm-river-motion-') as output:
        command = [os.environ.get('GODOT', '/Applications/Godot.app/Contents/MacOS/Godot'),
                   '--path', str(ROOT), '--log-file', output+'/engine.log',
                   '--script', 'res://tools/world/review_player_river_escape.gd', '--', '--output='+output]
        if args.case:
            command.append("--case="+args.case)
        if args.headless:
            command.insert(1, '--headless')
        print(output, flush=True)
        process = subprocess.Popen(command)
        try:
            status = process.wait(timeout=180)
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
