"""Run an intro/display validation with disposable engine logs and cleanup."""
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
script = "validate_world_collision_budget.gd" if "--physics" in sys.argv else "validate_fort_in_world.gd" if "--integration" in sys.argv else "validate_cart_rein_buffers.gd" if "--reins" in sys.argv else "validate_game_error_route.gd" if "--route" in sys.argv else "validate_intro_render_budget.gd"
with tempfile.TemporaryDirectory(prefix="tlm-intro-validation-") as output:
    process = subprocess.Popen(
        [GODOT, *(["--headless"] if "--headless" in sys.argv else []), "--path", str(ROOT), "--log-file", str(Path(output) / "engine.log"),
         "--max-fps", "60", "--script", "res://tools/world/" + script],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
    )
    errors = 0
    try:
        for line in process.stdout:
            if "ERROR:" in line or "SCRIPT ERROR:" in line:
                errors += 1
            if "The oil lamp" not in line:
                print(line, end="", flush=True)
        result = process.wait()
        if errors:
            print(f"Validation reported {errors} errors.", flush=True)
            result = result or 1
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    sys.exit(result)
