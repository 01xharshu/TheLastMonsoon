"""Verify a specified checkout's merged features in a disposable snapshot.

Unlike checking committed HEAD, --project includes that checkout's current edits.
No generated logs, reports, captures or save data are retained.
"""
import argparse
import os
from pathlib import Path
import shutil
import signal
import sys
import tempfile

sys.dont_write_bytecode = True
import check_game


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=check_game.ROOT)
    parser.add_argument("--cached", action="store_true",
                        help="Copy existing imports; does not verify a fresh import.")
    parser.add_argument("--native", action="store_true",
                        help="Render source checks with the host native renderer; no captures.")
    parser.add_argument("--godot", default=shutil.which("godot") or
                        "/Applications/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("checks", nargs="*", default=[])
    args = parser.parse_args()
    source = args.project.resolve()
    if not (source / "project.godot").is_file():
        parser.error("--project must identify the intended Godot checkout")
    names = args.checks or ["households", "merged_earthenware", "draft_teams", "architecture_boundaries",
                           "architecture_services", "architecture_navigation",
                           "save_flow", "rebellion_story"]
    for name in names:
        if not name.replace("_", "").isalnum():
            parser.error("Invalid check name: " + name)
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    print("Checking current files in", source, flush=True)
    with tempfile.TemporaryDirectory(prefix="tlm-merged-check-") as folder:
        directory = Path(folder)
        project = directory / "project"
        try:
            shutil.copytree(source, project, copy_function=check_game.copy_stable_file,
                            ignore=shutil.ignore_patterns(".git", ".godot", "WorkingAssets",
                                                         "__pycache__", "node_modules", ".next"))
            config = project / "project.godot"
            config.write_text(config.read_text().replace(
                "[application]", '[application]\nconfig/use_custom_user_dir=true\n'
                'config/custom_user_dir_name="' + directory.name + '"'))
            os.environ["TLM_SAVE_TEST_DIR"] = str(directory)
            os.environ["TLM_STORY_TEST_DIR"] = str(directory)
            if args.cached:
                cache = project / ".godot"
                cache.mkdir()
                shutil.copytree(source / ".godot/imported", cache / "imported",
                                copy_function=check_game.copy_stable_file)
                for name in ("global_script_class_cache.cfg", "uid_cache.bin"):
                    shutil.copy2(source / ".godot" / name, cache / name)
                print("Copied import cache; fresh imports NOT verified.", flush=True)
                passed = True
            else:
                passed = check_game.run_check(args.godot, project, directory,
                                              "IMPORT", ["--import"], 600)
            if not passed:
                return 1
            passed = check_game.run_check(args.godot, project, directory, "CODE",
                                         ["--script", "res://tools/maintenance/validate_code.gd"], 120,
                                         native=args.native)
            for name in names:
                if name == "packed":
                    platform = {"darwin": "macOS", "win32": "Windows Desktop"}.get(sys.platform, "Linux")
                    (project / "export_presets.cfg").write_text(
                        '[preset.0]\nname="Merged check"\nplatform="' + platform + '"\n'
                        'runnable=true\nexport_filter="all_resources"\ninclude_filter=""\n'
                        'exclude_filter="WorkingAssets/*,docs/*"\nexport_path=""\n'
                        'script_export_mode=1\n[preset.0.options]\n'
                        'application/bundle_identifier="org.thelastmonsoon.disposable"\n')
                    pack = directory / "merged.pck"
                    ok = check_game.run_check(args.godot, project, directory, "EXPORT",
                                              ["--export-pack", "Merged check", str(pack)], 300)
                    if ok:
                        isolated = directory / "packed_run"
                        isolated.mkdir()
                        ok = check_game.run_check(args.godot, isolated, directory, "PACKED_WORLD",
                                                  ["--main-pack", str(pack), "--fixed-fps", "60",
                                                   "--script", "res://tools/maintenance/smoke_game.gd",
                                                   "--", "--world"], 300)
                    passed = ok and passed
                    continue
                command = ["--fixed-fps", "60"]
                if name == "households":
                    command += ["res://tools/world/validate_cultivating_household.tscn"]
                else:
                    command += ["--script", "res://tools/world/validate_" + name + ".gd"]
                ok = check_game.run_check(args.godot, project, directory,
                                          name.upper(), command, 300, native=args.native)
                passed = ok and passed
                log = directory / (name.upper() + ".log")
                for line in log.read_text(errors="replace").splitlines():
                    if line.startswith(("HOUSE", "MERGED EARTHENWARE", "PLAYER_PATH", "ARCHITECTURE ",
                                        "REBELLION ", "SAVE FLOW")):
                        print(line, flush=True)
            print("MERGED FEATURES", "PASS" if passed else "FAIL", flush=True)
            return 0 if passed else 1
        finally:
            shutil.rmtree(check_game.user_data_directory(directory.name), ignore_errors=True)
            print("Temporary snapshot, logs and user data deleted on exit.", flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
