"""Native world review; captures are temporary and removed on every exit."""
import os
import signal
import subprocess
import tempfile
import time
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
def interrupted(signum, frame):
    raise SystemExit(128 + signum)
for sig in (signal.SIGINT, signal.SIGTERM):
    signal.signal(sig, interrupted)
with tempfile.TemporaryDirectory(prefix="tlm-urban-review-") as folder:
    env = os.environ.copy()
    env["TLM_URBAN_REVIEW_TEMP"] = folder
    print("URBAN_REVIEW_TEMP", folder, flush=True)
    process = subprocess.Popen(["/Applications/Godot.app/Contents/MacOS/Godot"] + (["--rendering-method", "gl_compatibility"] if "--compatibility" in sys.argv else []) + ["--path", str(ROOT), "--script", "tools/world/review_urban_west.gd"], cwd=ROOT, env=env)
    try:
        try:
            result = process.wait(timeout=300)
        except subprocess.TimeoutExpired:
            print("URBAN REVIEW TIMEOUT", flush=True)
            result = 1
        if any(Path(folder).glob("*.png")):
            print("TEMPORARY VIEWS READY FOR INSPECTION", flush=True)
            time.sleep(35)
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
raise SystemExit(result)
