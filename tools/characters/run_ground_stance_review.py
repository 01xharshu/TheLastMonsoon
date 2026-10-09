"""Run the reusable player stance check; disposable output always stays temporary."""
import argparse
import subprocess
import tempfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true", help="Show the actual player sequence at normal speed.")
    parser.add_argument("--world", action="store_true", help="Check the placed world cover and stance route.")
    parser.add_argument("--rebuild", action="store_true", help="Rebuild the six runtime garment fits from the retained complete body.")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    godot = "/Applications/Godot.app/Contents/MacOS/Godot"
    with tempfile.TemporaryDirectory(prefix="tlm-ground-stance-") as output:
        command = [godot, "--path", str(root), "--log-file", str(Path(output) / "godot.log")]
        if args.rebuild:
            command += ["--headless", "--script", "res://tools/characters/build_arjun_stance_fit.gd"]
        elif args.native:
            command += ["--script", "res://tools/characters/review_arjun_ground_stances.gd", "--", "--output-dir=" + output]
        else:
            script = "res://tools/world/validate_stealth_stance.gd" if args.world else "res://tools/characters/validate_arjun_ground_stance_isolated.gd"
            command += ["--headless", "--fixed-fps", "60", "--script", script]
        process = subprocess.Popen(command)
        try:
            return process.wait(timeout=90)
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
