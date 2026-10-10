"""Run focused performance checks with temporary output and bounded cleanup."""
from pathlib import Path
import argparse
import subprocess
import tempfile
import threading
import select
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"


def other_native_jobs(own_pid=None):
    result = subprocess.run(["/usr/bin/pgrep", "-fl", "Godot"], capture_output=True, text=True, check=False)
    jobs = []
    for line in result.stdout.splitlines():
        parts = line.split(maxsplit=1)
        if len(parts) == 2 and parts[0].isdigit() and parts[1].startswith(GODOT + " ") and "--headless" not in parts[1] and int(parts[0]) != own_pid:
            jobs.append(int(parts[0]))
    return jobs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("check", choices=["cow-metadata", "terrain", "bag", "npc", "feet", "humans", "roadside", "scripts", "frames", "route", "population", "traffic", "tutorial", "support", "coach", "continue", "combat", "cow", "menu"])
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--bullock", action="store_true", help="Check the actual bullock-cart driver with the coach validator.")
    parser.add_argument("--baseline", action="store_true", help="Print actual driver setup without requiring a cache hit.")
    parser.add_argument("--locations", action="store_true", help="Check driver cache identity across world locations and headings.")
    parser.add_argument("--runtime-fitting", action="store_true", help="Compare uncached fitting without loading-stage yielding.")
    parser.add_argument("--area", choices=["village", "civil_lines", "cantonment", "forest"], help="Verify just this walking segment through New Journey.")
    parser.add_argument("--skip-intro", action="store_true", help="Use the existing two-press skip in a focused walking check.")
    parser.add_argument("--profile-cloth", action="store_true", help="Attribute slow seated-driver garment fitting during the route.")
    parser.add_argument("--verbose", action="store_true", help="Include engine resource-leak diagnostics.")
    parser.add_argument("--sample", action="store_true", help="Sample only this check's native process after scene readiness.")
    parser.add_argument("--lod-sweep", action="store_true", help="Compare existing imported mesh LOD thresholds in the frame profiler.")
    parser.add_argument("--isolate", action="store_true", help="Temporarily isolate rendering, physics callbacks and animation in the village frame diagnostic.")
    parser.add_argument("--physics", action="store_true", help="Attribute physics callbacks instead of idle callbacks in scripts check.")
    parser.add_argument("--village", action="store_true", help="Attribute script callbacks near the village instead of Civil Lines.")
    parser.add_argument("--review", action="store_true", help="Keep temporary route or cow views available for up to 60 seconds before cleanup.")
    parser.add_argument("--quality", choices=["low","medium","high"], help="Use this quality in memory for a route or frame profile; do not change saved preferences.")
    args = parser.parse_args()
    scripts = {
        "cow-metadata": "tools/animals/validate_cow_surface_metadata.gd",
        "menu": "tools/world/validate_menu_integration.gd",
        "cow": "tools/animals/validate_cow_motion.gd",
        "combat": "tools/weapons/validate_combat_motion.gd",
        "continue": "tools/world/validate_resident_integration.gd",
        "coach": "tools/horses/validate_coachman_startup_cache.gd",
        "traffic": "tools/world/validate_city_route_population.gd",
        "tutorial": "tools/world/validate_morning_tutorial.gd",
        "support": "tools/world/validate_terrain_support_filter.gd",
        "population": "tools/world/validate_population_budget.gd",
        "terrain": "tools/world/validate_terrain_query_budget.gd",
        "bag": "tools/characters/validate_water_bag_contact_cache.gd",
        "npc": "tools/characters/validate_npc_animation_cache.gd",
        "feet": "tools/characters/validate_npc_foot_work.gd",
        "humans": "tools/characters/validate_human_scene_cache.gd",
        "roadside": "tools/world/validate_roadside_opportunities.gd",
        "scripts": "tools/world/profile_script_costs.gd",
        "frames": "tools/world/profile_frame_budget.gd",
        "route": "tools/world/validate_game_error_route.gd",
    }
    native = args.native or args.check in {"frames", "route"}
    if native:
        deadline = time.monotonic() + 240
        announced = False
        while other_native_jobs():
            if not announced:
                print("Waiting for the existing native renderer; no other process will be stopped.", flush=True)
                announced = True
            if time.monotonic() >= deadline:
                print("Native renderer remained occupied; no benchmark launched.", flush=True)
                return 2
            time.sleep(3)
    with tempfile.TemporaryDirectory(prefix="tlm-performance-") as output:
        directory = Path(output)
        command = [GODOT, *([] if native else ["--headless"]), "--path", str(ROOT),
                   "--log-file", str(directory / "engine.log"), "--max-fps", "120" if args.check == "frames" else "60",
                   "--script", "res://" + scripts[args.check]]
        if args.verbose: command.insert(1,"--verbose")
        extras = []
        if args.bullock: extras.append("--bullock")
        if args.baseline: extras.append("--baseline")
        if args.locations: extras.append("--locations")
        if args.runtime_fitting: extras.append("--runtime-fitting")
        if args.area: extras.append("--area=" + args.area)
        if args.skip_intro: extras.append("--skip-intro")
        if args.profile_cloth: extras.append("--profile-cloth")
        if args.check == "continue": extras.append("--continue")
        if args.lod_sweep: extras.append("--lod-sweep")
        if args.isolate: extras.append("--isolate")
        if args.physics: extras.append("--physics")
        if args.village: extras.append("--village")
        if args.review and args.check in {"route", "cow-metadata", "coach"}: extras.append("--review-dir=" + str(directory))
        if args.quality: extras.append("--quality=" + str(["low","medium","high"].index(args.quality)))
        if extras: command += ["--", *extras]
        environment = None
        if args.check == "continue":
            import os
            environment = dict(os.environ, TLM_TEST_SAVE_ROOT=str(directory))
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=environment)
        timed_out = threading.Event()
        finished = threading.Event()
        overlapped = threading.Event()

        def monitor_renderer():
            while not finished.wait(3):
                if process.poll() is not None:
                    return
                if other_native_jobs(process.pid):
                    overlapped.set()
                    print("Another native renderer started; stopping this check and discarding timing attribution.", flush=True)
                    process.terminate()
                    return

        if native:
            threading.Thread(target=monitor_renderer, daemon=True).start()

        def timeout():
            timed_out.set()
            process.kill()

        timeout_seconds = 600 if args.check in {"route", "frames", "traffic", "tutorial", "continue"} else 240
        timer = threading.Timer(timeout_seconds, timeout)
        timer.daemon = True
        timer.start()
        errors = 0
        sampled = False
        diagnostic_context = 0
        try:
            for line in process.stdout:
                if args.check in {"frames", "route"} and ("BUDGET START" in line or line.startswith("FRAME BUDGET {") or "GAME ERROR ROUTE READY" in line or "PERFORMANCE SNAPSHOT" in line):
                    resident = subprocess.run(["/bin/ps", "-o", "rss=", "-p", str(process.pid)], capture_output=True, text=True, check=False)
                    if resident.stdout.strip().isdigit():
                        print(f"PROCESS RESIDENCY | rss_bytes {int(resident.stdout.strip()) * 1024} | own process; engine/GPU counters are separate and must not be added", flush=True)
                if line.startswith(("ERROR:", "SCRIPT ERROR:", "SHADER ERROR:", "WARNING:")):
                    errors += 1
                    diagnostic_context = 5
                if line.startswith("SCRIPT ERROR:") and any(kind in line for kind in ("Compile Error:", "Parse Error:")):
                    process.terminate()
                if diagnostic_context or line.startswith(("FAIL ","Leaked instance:","Resource still in use:")) or any(marker in line for marker in (
                    "PERFORMANCE SNAPSHOT", "COW METADATA", "MENU INTEGRATION", "COW MOTION:", "COMBAT MOTION", "RESIDENT_WORLD_RESULT", "COACHMAN CACHE", "COACHMAN CLOTH COST", "CITY_POPULATION_RESULT", "MORNING TUTORIAL", "BUDGET", "SCRIPT COST", "CONTACT CACHE", "NPC ANIMATION CACHE", "NPC FRAME WORK", "HUMAN CACHE", "ROADSIDE OPPORTUNITIES", "PIXEL PARITY", "GAME ERROR ROUTE", "RENDER REVIEW", '"routes"',
                )):
                    print(line, end="", flush=True)
                    diagnostic_context = max(0, diagnostic_context - 1)
                if args.sample and not sampled and "FRAME BUDGET START" in line:
                    sampled = True
                    stack = directory / "sample.txt"
                    subprocess.run(["/usr/bin/sample", str(process.pid), "3", "-file", str(stack)],
                                   capture_output=True, timeout=15, check=False)
                    if stack.exists():
                        graph = stack.read_text().split("Call graph:", 1)[-1]
                        if "???  (in Godot)" in graph:
                            print("Own process sampled; engine frames lack symbols, so engine-function attribution is unavailable.", flush=True)
                        else:
                            print("OWN PROCESS STACK SAMPLE\n" + "\n".join(graph.splitlines()[:40]), flush=True)
            result = process.wait()
        finally:
            finished.set()
            timer.cancel()
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        if timed_out.is_set():
            print(f"Check exceeded its {timeout_seconds}-second limit.", flush=True)
        if args.review and args.check in {"route", "cow-metadata", "coach"} and result == 0 and not (errors or timed_out.is_set() or overlapped.is_set()):
            print("TEMPORARY REVIEW DIRECTORY " + str(directory), flush=True)
            # A reviewer can inspect local images and send Enter to clean up.
            # Timeout/EOF/interruption also leaves the TemporaryDirectory scope.
            if select.select([sys.stdin], [], [], 60)[0]:
                sys.stdin.readline()
        print("Temporary logs and stack samples deleted.", flush=True)
        return result or int(bool(errors) or timed_out.is_set() or overlapped.is_set())


if __name__ == "__main__":
    raise SystemExit(main())
