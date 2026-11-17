"""Native grass A/B/A with a git baseline shader and disposable output."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"


def main():
    baseline = subprocess.check_output(
        ["git", "show", "HEAD:world/suryagarh/shaders/grass_blades.gdshader"], cwd=ROOT
    )
    with tempfile.TemporaryDirectory(prefix="tlm-grass-shader-") as output:
        directory = Path(output)
        shader = directory / "baseline.gdshader"
        shader.write_bytes(baseline)
        environment = os.environ.copy()
        environment["TLM_GRASS_BASELINE_SHADER"] = str(shader)
        result = subprocess.run(
            [GODOT, "--path", str(ROOT), "--rendering-driver", "metal",
             "--resolution", "1280x720", "--disable-vsync", "--log-file", str(directory / "engine.log"),
             "--script", "res://tools/world/validate_grass_shader.gd"],
            env=environment, timeout=180,
        )
        log = (directory / "engine.log").read_text()
        errors = any(marker in log for marker in ("SCRIPT ERROR:", "SHADER ERROR:", "ERROR:"))
        return result.returncode or int(errors or "GRASS SHADER ALL PASS" not in log)


if __name__ == "__main__":
    raise SystemExit(main())
