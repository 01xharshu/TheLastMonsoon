#!/usr/bin/env python3
"""Run native sky route; all optional test images are automatically discarded."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")

def main():
    # TemporaryDirectory cleans success, failures and KeyboardInterrupt alike.
    with tempfile.TemporaryDirectory(prefix="monsoon-sky-review-") as output:
        process = subprocess.Popen([GODOT, "--path", str(ROOT), "--script",
                                    "tools/world/review_sky_world.gd", "--", "--output=" + output])
        try:
            return process.wait(timeout=180)
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()

if __name__ == "__main__":
    raise SystemExit(main())
