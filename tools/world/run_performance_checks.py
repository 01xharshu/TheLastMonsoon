"""Run focused performance checks with temporary output and bounded cleanup."""
from pathlib import Path
import argparse
import subprocess
import tempfile
import threading
import select
import sys

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("check", choices=["terrain", "bag", "npc", "feet", "humans", "roadside", "scripts", "frames", "route"])
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--sample", action="store_true", help="Sample only this check's native process after scene readiness.")
    parser.add_argument("--lod-sweep", action="store_true", help="Compare existing imported mesh LOD thresholds in the frame profiler.")
    parser.add_argument("--isolate", action="store_true", help="Temporarily isolate rendering, physics callbacks and animation in the village frame diagnostic.")
    parser.add_argument("--physics", action="store_true", help="Attribute physics callbacks instead of idle callbacks in scripts check.")
    parser.add_argument("--village", action="store_true", help="Attribute script callbacks near the village instead of Civil Lines.")
    parser.add_argument("--review", action="store_true", help="Keep temporary route views available for up to 60 seconds before cleanup.")
    parser.add_argument("--quality", choices=["low","medium","high"], help="Use this quality in memory for a route or frame profile; do not change saved preferences.")
    args = parser.parse_args()
    scripts = {
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
    with tempfile.TemporaryDirectory(prefix="tlm-performance-") as output:
        directory = Path(output)
        command = [GODOT, *([] if native else ["--headless"]), "--path", str(ROOT),
                   "--log-file", str(directory / "engine.log"), "--max-fps", "120" if args.check == "frames" else "60",
                   "--script", "res://" + scripts[args.check]]
        extras = []
        if args.lod_sweep: extras.append("--lod-sweep")
        if args.isolate: extras.append("--isolate")
        if args.physics: extras.append("--physics")
        if args.village: extras.append("--village")
        if args.review and args.check == "route": extras.append("--review-dir=" + str(directory))
        if args.quality: extras.append("--quality=" + str(["low","medium","high"].index(args.quality)))
        if extras: command += ["--", *extras]
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        timed_out = threading.Event()

        def timeout():
            timed_out.set()
            process.kill()

        timer = threading.Timer(240, timeout)
        timer.daemon = True
        timer.start()
        errors = 0
        sampled = False
        diagnostic_context = 0
        try:
            for line in process.stdout:
                if line.startswith(("ERROR:", "SCRIPT ERROR:", "SHADER ERROR:", "WARNING:")):
                    errors += 1
                    diagnostic_context = 5
                if line.startswith("SCRIPT ERROR:") and any(kind in line for kind in ("Compile Error:", "Parse Error:")):
                    process.terminate()
                if diagnostic_context or any(marker in line for marker in (
                    "BUDGET", "SCRIPT COST", "CONTACT CACHE", "NPC ANIMATION CACHE", "NPC FRAME WORK", "HUMAN CACHE", "ROADSIDE OPPORTUNITIES", "PIXEL PARITY", "GAME ERROR ROUTE", "RENDER REVIEW", '"routes"',
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
            timer.cancel()
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        if timed_out.is_set():
            print("Check exceeded its 240-second limit.", flush=True)
        if args.review and args.check == "route":
            print("TEMPORARY REVIEW DIRECTORY " + str(directory), flush=True)
            # A reviewer can inspect local images and send Enter to clean up.
            # Timeout/EOF/interruption also leaves the TemporaryDirectory scope.
            if select.select([sys.stdin], [], [], 60)[0]:
                sys.stdin.readline()
        print("Temporary logs and stack samples deleted.", flush=True)
        return result or int(bool(errors) or timed_out.is_set())


if __name__ == "__main__":
    raise SystemExit(main())
