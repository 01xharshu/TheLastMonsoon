"""Run delayed cart save restoration with disposable saves and logs."""
from pathlib import Path
import argparse
import os
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--integrated", action="store_true")
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="tlm-cart-continue-") as temporary:
        env = dict(os.environ, TLM_CART_CONTINUE_SAVE_ROOT=str(Path(temporary) / "saves"))
        command = [args.godot, "--path", str(args.project.resolve()), "--log-file", str(Path(temporary) / "godot.log"), "--script", "res://tools/world/validate_cart_continue.gd"]
        if not args.native:
            command.insert(1, "--headless")
        if args.integrated:
            command.extend(["--", "--integrated"])
        try:
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=480 if args.integrated else 150)
        except subprocess.TimeoutExpired as failure:
            print("CART CONTINUE TIMEOUT; temporary saves/logs removed")
            output = (failure.stdout or b"") + (failure.stderr or b"")
            print(output[-4000:].decode(errors="replace"))
            return 1
        output = result.stdout + result.stderr
        print(output[-8000:])
        passed = result.returncode == 0 and '\"status\":\"PASS\"' in output and "SCRIPT ERROR" not in output and "ERROR:" not in output
        return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
