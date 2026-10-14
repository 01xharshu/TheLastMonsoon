"""Verify the ordered rebellion and consignment in a disposable project snapshot."""
import argparse
import importlib.util
import os
from pathlib import Path
import shutil
import signal
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
CHECKS = {
    "budget": ("validate_expanded_world_budget.gd", False),
    "portrait": ("bake_wanted_portrait.gd", False),
    "continuous": ("validate_consignment_story.gd", True),
    "motion_focused": ("validate_consignment_story.gd", True),
    "motion": ("validate_consignment_story.gd", False),
    "focused": ("validate_consignment_story.gd", True),
    "world": ("validate_consignment_story.gd", False),
    "travel": ("validate_consignment_story.gd", False),
    "first": ("review_rebellion_story.gd", False),
    "lessons": ("validate_dev_story.gd", False),
    "rebellion": ("validate_rebellion_story.gd", False),
    "save": ("validate_save_flow.gd", False),
    "objectives": ("validate_architecture_services.gd", False),
    "onboarding": ("validate_morning_tutorial.gd", False),
    "community": ("validate_community_story.gd", False),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--review", action="store_true", help="Capture native scenes temporarily for inspection; delete on exit")
    parser.add_argument("--cached", action="store_true", help="Reuse source import cache in the disposable copy; still run incremental import")
    parser.add_argument("--checks", nargs="+", choices=CHECKS, default=[key for key in CHECKS if key not in ("portrait","motion","motion_focused","budget")])
    args = parser.parse_args()
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    spec = importlib.util.spec_from_file_location("checks", ROOT / "tools/maintenance/check_game.py")
    checks = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checks)
    with tempfile.TemporaryDirectory(prefix="tlm-ordered-rebellion-") as folder:
        directory = Path(folder)
        project = directory / "project"
        shutil.copytree(args.project, project, copy_function=checks.copy_stable_file,
                        ignore=shutil.ignore_patterns(".git", *([] if args.cached else [".godot"]), "WorkingAssets", "__pycache__",
                                                     "node_modules", ".next"))
        config = project / "project.godot"
        config.write_text(config.read_text().replace(
            "[application]", '[application]\nconfig/use_custom_user_dir=true\n'
            f'config/custom_user_dir_name="{directory.name}"'))
        binary = shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
        original_environment = {key: os.environ.get(key) for key in
                                ("TLM_STORY_TEST_DIR", "TLM_SAVE_TEST_DIR", "TLM_CONSIGNMENT_FOCUSED", "TLM_CONSIGNMENT_REVIEW_PATH", "TLM_COMMUNITY_WORLD", "TLM_COMMUNITY_SAVE_DIR", "TLM_CONSIGNMENT_TRAVEL", "TLM_CHASE_MOTION", "TLM_CHASE_CONTINUOUS")}
        os.environ["TLM_STORY_TEST_DIR"] = str(directory)
        os.environ["TLM_SAVE_TEST_DIR"] = str(directory)
        os.environ["TLM_COMMUNITY_SAVE_DIR"] = str(directory)
        if args.review:
            os.environ["TLM_CONSIGNMENT_REVIEW_PATH"] = str(directory)
            print("REVIEW_DIR " + str(directory), flush=True)
        try:
            if not checks.run_check(binary, project, directory, "IMPORT", ["--import"], 420):
                return 1
            passed = True
            for label in args.checks:
                os.environ["TLM_CHASE_CONTINUOUS"] = "1" if label=="continuous" else "0"
                os.environ["TLM_CHASE_MOTION"] = "1" if label in ("motion","motion_focused") else "0"
                script, focused = CHECKS[label]
                os.environ["TLM_COMMUNITY_WORLD"] = "1" if label=="community" else "0"
                os.environ["TLM_CONSIGNMENT_TRAVEL"] = "1" if label=="travel" else "0"
                os.environ["TLM_CONSIGNMENT_FOCUSED"] = "1" if focused else "0"
                ok = checks.run_check(binary, project, directory, label.upper(),
                                      ["--fixed-fps", "60", "--script", "res://tools/world/" + script],
                                      600, native=args.native)
                for line in (directory / (label.upper() + ".log")).read_text().splitlines():
                    if any(key in line for key in ("GRADE PEAK ", "CONSIGNMENT ", "REBELLION WORLD:", "REBELLION STORY:",
                                                   "DEV STORY:", "MORNING TUTORIAL:", "COMMUNITY WORLD",
                                                   "SAVE FLOW VALIDATION", "ARCHITECTURE SERVICES")):
                        print(line, flush=True)
                if script=="validate_consignment_story.gd" and "CONSIGNMENT STORY: PASS" not in (directory / (label.upper()+".log")).read_text():
                    print(label.upper()+" FAIL: process exited before explicit completion gate",flush=True)
                    ok=False
                if script=="validate_expanded_world_budget.gd" and "CONSIGNMENT EXPANSION BUDGET: SAMPLED" not in (directory / (label.upper()+".log")).read_text():
                    print("BUDGET FAIL: process exited before sampling completed",flush=True)
                    ok=False
                passed = ok and passed
                # Keep the failed snapshot's diagnostics concise; fix before broadening.
                if not ok:
                    break
            if args.review:
                print("REVIEW_READY " + str(directory), flush=True)
                for _ in range(90):
                    if (directory / "review_done").exists():
                        break
                    time.sleep(1)
            return 0 if passed else 1
        finally:
            shutil.rmtree(checks.user_data_directory(directory.name), ignore_errors=True)
            for key, value in original_environment.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value


if __name__ == "__main__":
    sys.exit(main())
