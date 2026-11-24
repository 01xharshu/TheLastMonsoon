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


def other_engine_jobs(own_pid=None):
    jobs = []
    for line in subprocess.check_output(["ps", "-axo", "pid=,command="], text=True).splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) == 2 and fields[1].startswith(GODOT + " ") and int(fields[0]) != own_pid:
            jobs.append(int(fields[0]))
    return jobs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", action="store_true")
    parser.add_argument("--reverse-lod-crossing", action="store_true")
    parser.add_argument("--stagger-live-population", action="store_true")
    parser.add_argument("--headless-population-trace", action="store_true")
    parser.add_argument("--trace-live-population", action="store_true")
    parser.add_argument("--live-lod", choices=["original", "candidate"])
    parser.add_argument("--geometry", action="store_true")
    parser.add_argument("--moving-lod", action="store_true")
    parser.add_argument("--tree-lod", action="store_true")
    parser.add_argument("--render-sampling", action="store_true")
    parser.add_argument("--preview", action="store_true", help="Hold temporary native study images for automation review until stdin newline")
    parser.add_argument("--area", choices=["village", "civil_lines", "cantonment", "forest", "broadleaf_close"], default="village")
    parser.add_argument("--walk-reference", action="store_true", help="Profile with only the new walking cadence disabled")
    parser.add_argument("--residents", action="store_true")
    parser.add_argument("--bag", action="store_true")
    parser.add_argument("--bag-reference", action="store_true", help="Profile with the original coat contact scan")
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--world", action="store_true")
    args = parser.parse_args()
    if args.headless_population_trace:
        if not args.live_lod or args.native or args.geometry or args.moving_lod or args.tree_lod or args.world or args.render_sampling:
            parser.error("--headless-population-trace requires --live-lod without native options")
        args.trace_live_population = True
    if args.moving_lod:
        args.tree_lod = True
        args.area = "broadleaf_close"
    if args.tree_lod:
        args.geometry = True
    if args.world or args.geometry or args.render_sampling or (args.live_lod and not args.headless_population_trace):
        args.native = True
    if args.native:
        needs_quiet_window = bool(args.geometry or args.live_lod)
        deadline = time.monotonic() + (600 if needs_quiet_window else 120)
        competing_jobs = other_engine_jobs if args.geometry or args.live_lod else other_native_jobs
        quiet_since = None
        announced = False
        while True:
            jobs = competing_jobs()
            if jobs:
                quiet_since = None
            elif quiet_since is None:
                quiet_since = time.monotonic()
            if not jobs and (not needs_quiet_window or time.monotonic() - quiet_since >= 20):
                break
            if not announced:
                print("Waiting for an uncontended Godot window" + (" (20 seconds quiet)." if needs_quiet_window else "."), flush=True)
                announced = True
            if time.monotonic() >= deadline:
                print("Godot runtime remained occupied; check not launched.", flush=True)
                return 2
            time.sleep(2)
    script = "profile_script_costs.gd" if args.profile else ("validate_resident_pose_budget.gd" if args.residents else "validate_npc_pose_budget.gd")
    if args.bag:
        script = "../characters/validate_water_bag_contact_cache.gd"
    marker = "SCRIPT COST PROFILE: COMPLETE" if args.profile else ("RESIDENT POSE BUDGET PASS" if args.residents else "NPC POSE BUDGET PASS")
    if args.bag:
        marker = "WATER BAG CONTACT CACHE"
    if args.render_sampling:
        script = "validate_render_sampling.gd"
        marker = "RENDER SAMPLING PASS"
    if args.geometry:
        script = "profile_frame_budget.gd"
        marker = "FRAME BUDGET PROFILE: COMPLETE"
    if args.live_lod:
        script = "validate_game_error_route.gd"
        marker = "GAME ERROR ROUTE: PASS"
    with tempfile.TemporaryDirectory(prefix="tlm-performance-" if args.preview else "tlm-npc-pose-") as temporary:
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
            command += ["--rendering-driver", "metal", "--resolution", "1280x720", "--disable-vsync"] if args.native else (["--headless", "--fixed-fps", "60"] if args.headless_population_trace else ["--headless"])
            command += ["--script", "res://tools/world/" + script, "--"]
            if args.live_lod:
                command += ["--quality=1", "--skip-intro", "--live-lod-route", "--area=" + args.area]
                if args.stagger_live_population:
                    command += ["--stagger-live-population"]
                if args.trace_live_population:
                    command += ["--trace-live-population"]
                if args.preview:
                    command += ["--review-dir=" + str(directory)]
                if args.reverse_lod_crossing:
                    command += ["--reverse-lod-crossing"]
                if args.live_lod == "candidate":
                    command += ["--live-tree-lod"]
            if args.geometry:
                command += ["--geometry-attribution", "--area=" + args.area, "--quality=1", "--force-render-sampling"]
                if args.tree_lod:
                    command += ["--tree-lod"]
                if args.moving_lod:
                    command += ["--moving-lod"]
                if args.preview:
                    command += ["--review-dir=" + str(directory)]
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
                    if competing_jobs(process.pid):
                        overlapped.set()
                        print("Another competing Godot job started; discarding this check. PIDs=" + str(competing_jobs(process.pid)), flush=True)
                        process.terminate()
                        return
            if args.native:
                threading.Thread(target=monitor, daemon=True).start()
            timer = threading.Timer(600 if args.geometry else 360, process.kill)
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
            if args.preview and not result and not errors and not overlapped.is_set():
                print("PREVIEW_READY " + str(directory), flush=True)
                input()
            return result or int(errors or marker not in log or overlapped.is_set())
        finally:
            shutil.rmtree(userdata, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
