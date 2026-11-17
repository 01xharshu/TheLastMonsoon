"""Run NPC pose checks with disposable project/userdata and no retained output."""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile
import threading
import time
from run_performance_checks import other_native_jobs

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", action="store_true")
    parser.add_argument("--walk-reference", action="store_true", help="Profile with only the new walking cadence disabled")
    parser.add_argument("--residents", action="store_true")
    parser.add_argument("--bag", action="store_true")
    parser.add_argument("--bag-reference", action="store_true", help="Profile with the original coat contact scan")
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--world", action="store_true")
    args = parser.parse_args()
    if args.world:
        args.native = True
    if args.native:
        deadline = time.monotonic() + 120
        announced = False
        while other_native_jobs():
            if not announced:
                print("Waiting for the other native renderer; no other job will be stopped.", flush=True)
                announced = True
            if time.monotonic() >= deadline:
                print("Native renderer remained occupied; check not launched.", flush=True)
                return 2
            time.sleep(2)
    script = "profile_script_costs.gd" if args.profile else ("validate_resident_pose_budget.gd" if args.residents else "validate_npc_pose_budget.gd")
    if args.bag:
        script = "../characters/validate_water_bag_contact_cache.gd"
    marker = "SCRIPT COST PROFILE: COMPLETE" if args.profile else ("RESIDENT POSE BUDGET PASS" if args.residents else "NPC POSE BUDGET PASS")
    if args.bag:
        marker = "WATER BAG CONTACT CACHE"
    with tempfile.TemporaryDirectory(prefix="tlm-npc-pose-") as temporary:
        directory = Path(temporary)
        project = directory / "project"
        project.mkdir()
        userdata = Path.home() / "Library/Application Support" / directory.name
        try:
            for entry in ROOT.iterdir():
                if entry.name not in (".git", "project.godot"):
                    (project / entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
            config = (ROOT / "project.godot").read_text().replace(
                "[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + directory.name + '"', 1)
            (project / "project.godot").write_text(config)
            environment = dict(os.environ, TLM_EXPECT_USER_DATA=str(userdata))
            command = [GODOT, "--path", str(project), "--log-file", str(directory / "engine.log")]
            command += ["--rendering-driver", "metal", "--resolution", "1280x720", "--disable-vsync"] if args.native else ["--headless"]
            command += ["--script", "res://tools/world/" + script, "--"]
            if args.profile:
                command += ["--village"]
                if args.walk_reference:
                    command += ["--walk-reference"]
                if args.bag_reference:
                    command += ["--water-bag-contact-reference"]
            if args.world:
                command += ["--world"]
            process = subprocess.Popen(command, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            finished = threading.Event()
            overlapped = threading.Event()
            def monitor():
                while not finished.wait(.5):
                    if process.poll() is not None:
                        return
                    if other_native_jobs(process.pid):
                        overlapped.set()
                        print("Another native renderer started; discarding this check.", flush=True)
                        process.terminate()
                        return
            if args.native:
                threading.Thread(target=monitor, daemon=True).start()
            timer = threading.Timer(360, process.kill)
            timer.start()
            try:
                for line in process.stdout:
                    print(line, end="", flush=True)
                    if line.startswith(("SCRIPT ERROR:", "SHADER ERROR:", "ERROR:")):
                        process.terminate()
                result = process.wait()
            finally:
                finished.set()
                timer.cancel()
                if process.poll() is None:
                    process.kill()
                    process.wait()
            log = (directory / "engine.log").read_text()
            errors = any(part in log for part in ("SCRIPT ERROR:", "SHADER ERROR:", "ERROR:"))
            return result or int(errors or marker not in log or overlapped.is_set())
        finally:
            shutil.rmtree(userdata, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
