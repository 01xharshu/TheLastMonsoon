"""Review actual terrain/buildings. Temporary screenshots are always deleted."""
import os
import signal
import subprocess
import sys
import tempfile
import time
import threading
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
def interrupted(signum, frame):
    raise SystemExit(128 + signum)
for sig in (signal.SIGINT, signal.SIGTERM):
    signal.signal(sig, interrupted)
with tempfile.TemporaryDirectory(prefix="tlm-density-") as folder:
    env = dict(os.environ, TLM_DENSITY_TEMP=folder)
    args = ["/Applications/Godot.app/Contents/MacOS/Godot", "--path", str(ROOT), "--fixed-fps", "60", "--script", "tools/world/review_countryside_density.gd"]
    if "--contact-only" in sys.argv:
        args.insert(1, "--headless")
    extra = [flag for flag in ("--isolated", "--views-only", "--contact-only") if flag in sys.argv]
    if extra:
        args += ["--"] + extra
    print("DENSITY_TEMP", folder, flush=True)
    diagnostics = []
    process = subprocess.Popen(args, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    def relay():
        for line in process.stdout:
            print(line, end="", flush=True)
            if line.lstrip().startswith(("SCRIPT ERROR:", "ERROR:")):
                diagnostics.append(line.strip())
    reader = threading.Thread(target=relay, daemon=True)
    reader.start()
    result = 1
    try:
        try:
            result = process.wait(timeout=300)
        except subprocess.TimeoutExpired:
            print("DENSITY REVIEW TIMEOUT", flush=True)
            result = 124
        reader.join(timeout=2)
        if diagnostics:
            result = 1
            print("DENSITY ENGINE DIAGNOSTICS", len(diagnostics), flush=True)
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
