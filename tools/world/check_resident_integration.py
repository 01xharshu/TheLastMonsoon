"""Check real New Journey/Continue resident and delivery owners using disposable saves."""
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENGINE = "/Applications/Godot.app/Contents/MacOS/Godot"


def main():
    with tempfile.TemporaryDirectory(prefix="tlm-resident-continue-") as folder:
        environment = dict(os.environ, TLM_TEST_SAVE_ROOT=str(Path(folder) / "saves"))
        result = subprocess.run(
            [ENGINE, "--headless", "--path", str(ROOT), "--log-file",
             str(Path(folder) / "engine.log"), "--script",
             "res://tools/world/validate_resident_integration.gd", "--", "--continue"],
            cwd=ROOT, env=environment, capture_output=True, text=True, timeout=720,
        )
        output = result.stdout + result.stderr
        failed = result.returncode != 0 or "SCRIPT ERROR:" in output or "\nERROR:" in output
        for line in output.splitlines():
            if line.startswith(("RESIDENT_WORLD_RESULT", "DELIVERY_", "GOODS_BLOCKER")):
                print(line)
        if failed:
            print("\n".join(output.splitlines()[-15:]))
        return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
