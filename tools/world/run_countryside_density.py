"""Review actual terrain/buildings. Temporary screenshots are always deleted."""
import os
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
def interrupted(signum, frame):
    raise SystemExit(128 + signum)
for sig in (signal.SIGINT, signal.SIGTERM):
    signal.signal(sig, interrupted)
with tempfile.TemporaryDirectory(prefix="tlm-density-") as folder:
    env = dict(os.environ, TLM_DENSITY_TEMP=folder)
    args = ["/Applications/Godot.app/Contents/MacOS/Godot", "--path", str(ROOT), "--fixed-fps", "60", "--script", "tools/world/review_countryside_density.gd"]
    extra = [flag for flag in ("--isolated", "--views-only") if flag in sys.argv]
    if extra:
        args += ["--"] + extra
    print("DENSITY_TEMP", folder, flush=True)
    process = subprocess.Popen(args, cwd=ROOT, env=env)
    try:
        result = process.wait(timeout=300)
        print("REVIEW_IMAGES_READY", folder, flush=True)
        if "--inspect" in sys.argv:
            time.sleep(55)
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
raise SystemExit(result)
