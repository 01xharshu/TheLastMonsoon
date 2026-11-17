"""Verify player idle in a disposable project/save directory; retain no output."""
import argparse
import importlib.util
import os
from pathlib import Path
import shutil
import signal
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("game_checks", ROOT / "tools/maintenance/check_game.py")
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--regressions", action="store_true", help="Check AnimationTree, walk contact and crouch/prone cache integration")
    parser.add_argument("--review", action="store_true", help="Pause for temporary native world image inspection before cleanup")
    parser.add_argument("--world-only", action="store_true", help="Run only the normal populated-world integration")
    parser.add_argument("--world", action="store_true", help="Also exercise normal title/loading/opening/populated world")
    parser.add_argument("--native", action="store_true", help="Use native rendering; focused check covers ground ownership")
    args = parser.parse_args()
    args.world = args.world or args.world_only
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    with tempfile.TemporaryDirectory(prefix="tlm-long-idle-") as folder:
        directory = Path(folder)
        project = directory / "project"
        print("Preparing disposable idle project", flush=True)
        # Include the current imported cache; fresh checkouts import below.
        shutil.copytree(ROOT, project, copy_function=checks.copy_stable_file,
                        ignore=shutil.ignore_patterns(".git", "WorkingAssets", "__pycache__", "node_modules", ".next"))
        config = project / "project.godot"
        config.write_text(config.read_text().replace("[application]", "[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=\"" + directory.name + "\""))
        try:
            binary = "/Applications/Godot.app/Contents/MacOS/Godot" if sys.platform == "darwin" else "godot"
            if not (project / ".godot/global_script_class_cache.cfg").exists():
                if not checks.run_check(binary, project, directory, "IMPORT", ["--editor", "--import", "--quit"], 240):
                    return 1
            os.environ["TLM_IDLE_WORLD_REVIEW"] = str(directory) if args.review else ""
            os.environ["TLM_IDLE_GROUND_ONLY"] = "1" if args.native else "0"
            if args.regressions:
                for label, script in [("MOTION_TREE", "validate_arjun_motion_tree.gd"), ("WALK", "validate_arjun_walk_contact.gd"), ("STANCES", "validate_arjun_ground_stance_isolated.gd")]:
                    if not checks.run_check(binary, project, directory, label, ["--script", "res://tools/characters/" + script], 120, native=args.native):
                        return 1
            if not args.world_only and not args.regressions and not checks.run_check(binary, project, directory, "IDLE", ["--script", "res://tools/characters/validate_arjun_long_idle.gd"], 240, native=args.native):
                return 1
            if args.world:
                if not checks.run_check(binary, project, directory, "IDLE_WORLD", ["--script", "res://tools/world/validate_long_idle_integration.gd"], 420, native=args.native):
                    return 1
            if args.review and list(directory.glob("world_*.png")):
                print("Temporary world review: " + str(directory), flush=True)
                input("Press Enter after review; images, logs and saves will be deleted.\n")
            return 0
        finally:
            shutil.rmtree(checks.user_data_directory(directory.name), ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
