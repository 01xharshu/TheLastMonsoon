#!/usr/bin/env python3
"""Disposable community mission verification; never writes a player's saves."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--native', action='store_true')
parser.add_argument('--world', action='store_true')
parser.add_argument('--inspect', action='store_true')
args = parser.parse_args()
project = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='tlm-community-') as temporary:
    environment = dict(os.environ, TLM_COMMUNITY_WORLD='1' if args.world else 'focused')
    environment['TLM_COMMUNITY_SAVE_DIR'] = temporary
    command = ['/Applications/Godot.app/Contents/MacOS/Godot', '--path', str(project), '--log-file', str(Path(temporary) / 'engine.log')]
    if args.native:
        command.extend(['--rendering-driver', 'metal', '--resolution', '1280x720'])
        environment['TLM_COMMUNITY_IMAGES'] = temporary
    else:
        command.append('--headless')
    command.extend(['--script', 'res://tools/world/validate_community_story.gd'])
    print('Temporary review directory:', temporary, flush=True)
    process = subprocess.Popen(command, env=environment)
    try:
        code = process.wait(timeout=300)
        print('Community verification exit:', code, flush=True)
        if args.inspect:
            input('Finish temporary image inspection, then press Enter: ')
        raise SystemExit(code)
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        # TemporaryDirectory removes saves and images after the child has stopped.
