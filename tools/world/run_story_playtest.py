"""Run missing story routes or manual play in an isolated disposable snapshot.

Example: python3 tools/world/run_story_playtest.py --native --checks dev_world clock
Manual: python3 tools/world/run_story_playtest.py --manual --timeout 3600
All saves, captures, logs and the snapshot are removed on exit/interruption.
"""
import argparse
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]

def run_compact(checks, *args, **kwargs):
    """Keep diagnostic storms concise; the complete log remains temporary."""
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        ok = checks.run_check(*args, **kwargs)
    diagnostics = 0
    for line in output.getvalue().splitlines():
        if " × " in line:
            diagnostics += 1
            if diagnostics <= 5:
                print(line, flush=True)
        elif "exit=" in line or "TIMEOUT" in line or line.startswith("GAME ERROR ROUTE:"):
            print(line, flush=True)
    if diagnostics > 5:
        print(f"  {diagnostics - 5} additional diagnostic groups; run failed, full temporary log retained until cleanup", flush=True)
    return ok
CHECKS = {
    "dev_world": "review_dev_story.gd",
    "opening": "validate_opening_menu_route.gd",
    "clock": "validate_mission_clock.gd",
    "daily": "validate_daily_errands.gd",
    "expanded": "validate_expanded_errands.gd",
    "intro": "validate_game_error_route.gd",
    "wick_cut": "validate_opening_integration.gd",
    "medicine": "validate_expanded_errands.gd",
    "money": "validate_expanded_errands.gd",
    "passenger": "validate_passenger_contact.gd",
    "safety": "validate_player_safety.gd",
    "parking": "validate_delivery_parking.gd",
    "guard_release": "validate_dev_guard_release.gd",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true")
    parser.add_argument("--manual", action="store_true")
    parser.add_argument("--natural", action="store_true", help="Play Dev acting at normal elapsed time")
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--quality", type=int, choices=[0, 1, 2], help="Graphics preset for the disposable test only")
    parser.add_argument("--review-seconds", type=int, choices=range(0, 61), default=0, help="Keep temporary frames briefly for inspection")
    parser.add_argument("--keep-going", action="store_true", help="Run independent branches even after a failed check")
    parser.add_argument("--diagnose-delivery", action="store_true", help="Instrument only the disposable snapshot's collision and shutdown failures")
    parser.add_argument("--diagnose-teardown", action="store_true", help="Test orderly drawable/resource retirement in the disposable snapshot")
    parser.add_argument("--checks", nargs="+", choices=CHECKS, default=list(CHECKS))
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("game_checks", ROOT / "tools/maintenance/check_game.py")
    checks = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checks)
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    binary = shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
    keys = ["TLM_STORY_TEST_DIR", "TLM_SAVE_TEST_DIR", "TLM_STORY_NATURAL", "TLM_EXPECT_USER_DATA", "TLM_OPENING_CUT_ONLY", "TLM_OPENING_TEST_OUTPUT", "TLM_ERRAND_ONLY"]
    previous = {key: os.environ.get(key) for key in keys}
    with tempfile.TemporaryDirectory(prefix="tlm-story-playtest-") as temporary:
        directory = Path(temporary)
        project = directory / "project"
        try:
            shutil.copytree(ROOT, project, copy_function=checks.copy_stable_file,
                            ignore=shutil.ignore_patterns(".git", "WorkingAssets", "__pycache__", "node_modules", ".next"))
            config = project / "project.godot"
            config.write_text(config.read_text().replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + directory.name + '"'))
            if args.diagnose_delivery:
                source = project / "world/suryagarh/errands/delivery_handover.gd"
                content = source.read_text()
                content = content.replace(
                    "if not is_finite(supported_y) or absf(supported_y-receiver.global_position.y)>.30:return false",
                    'if not is_finite(supported_y) or absf(supported_y-receiver.global_position.y)>.30:\n\t\tif not reported_blocker:\n\t\t\treported_blocker=true\n\t\t\tprint("DELIVERY_SUPPORT_DIAGNOSTIC ",request," at=",receiver.global_position," move=",motion," support=",supported_y," route=",route)\n\t\treturn false')
                content = content.replace(
                    "if safe[0]<.99 or not occupied.is_empty():\n\t\tif not reported_blocker:\n\t\t\treported_blocker=true",
                    'if safe[0]<.99 or not occupied.is_empty():\n\t\tif not reported_blocker:\n\t\t\tprint("DELIVERY_CAST_DIAGNOSTIC ",request," at=",receiver.global_position," motion=",motion," safe=",safe," occupied=",occupied," shape=",shape.global_transform," route=",route)\n\t\t\treported_blocker=true')
                source.write_text(content)
                source = project / "systems/save_manager.gd"
                source.write_text(source.read_text().replace("_quitting = true", '_quitting = true\n\tprint("STORY_TEST_QUIT_BEGIN")'))
            if args.diagnose_teardown:
                source = project / "systems/save_manager.gd"
                replacement = '''var held_meshes:Array[Mesh]=[]
\tvar held_materials:Array[Material]=[]
\tvar scene:Node=get_tree().current_scene
\tif is_instance_valid(scene):
\t\tfor mesh_node:MeshInstance3D in scene.find_children("*","MeshInstance3D",true,false):
\t\t\tif mesh_node.mesh==null:continue
\t\t\theld_meshes.append(mesh_node.mesh)
\t\t\tif mesh_node.material_override!=null:held_materials.append(mesh_node.material_override)
\t\t\tfor surface in mesh_node.mesh.get_surface_count():
\t\t\t\tvar material:Material=mesh_node.get_surface_override_material(surface)
\t\t\t\tif material!=null:held_materials.append(material)
\t\tscene.queue_free()
\t\tfor frame in 3:await get_tree().process_frame
\tprint("STORY_TEST_RETIRED_DRAWABLES meshes=",held_meshes.size()," materials=",held_materials.size())
\tget_tree().quit(exit_code)'''
                source.write_text(source.read_text().replace("get_tree().quit(exit_code)", replacement))
            if args.quality is not None:
                settings = checks.user_data_directory(directory.name)
                settings.mkdir(parents=True, exist_ok=True)
                (settings / "settings.cfg").write_text("[settings]\ngraphics_quality=" + str(args.quality) + "\nfullscreen=false\n")
            os.environ["TLM_STORY_TEST_DIR"] = temporary
            os.environ["TLM_SAVE_TEST_DIR"] = temporary
            os.environ["TLM_STORY_NATURAL"] = "1" if args.natural else "0"
            if not run_compact(checks, binary, project, directory, "IMPORT", ["--import"], args.timeout):
                return 1
            print("PLAYTEST_DIR " + temporary, flush=True)
            if args.manual:
                os.environ["TLM_EXPECT_USER_DATA"] = str(checks.user_data_directory(directory.name))
                command = [binary, "--path", str(project), "--windowed", "--resolution", "1280x720", "--position", "40,60", "--log-file", str(directory / "manual.log")]
                if sys.platform == "darwin":
                    command += ["--rendering-driver", "metal"]
                process = subprocess.Popen(command, start_new_session=True)
                try:
                    process.wait(timeout=args.timeout)
                    return process.returncode
                finally:
                    checks.stop_process(process)
                    process.wait()
            passed = True
            for label in args.checks:
                os.environ["TLM_OPENING_CUT_ONLY"] = "1" if label == "wick_cut" else "0"
                os.environ["TLM_OPENING_TEST_OUTPUT"] = temporary
                os.environ["TLM_ERRAND_ONLY"] = {"medicine": "urgent_medicine", "money": "emergency_money"}.get(label, "")
                command = ["--script", "res://tools/world/" + CHECKS[label]]
                if label == "safety":
                    command += ["--", "--output=" + temporary]
                if not args.native:
                    command = ["--fixed-fps", "20", *command]
                if not run_compact(checks, binary, project, directory, label.upper(), command, args.timeout, native=args.native):
                    passed = False
                    if not args.keep_going:
                        return 1
                for line in (directory / (label.upper() + ".log")).read_text().splitlines():
                    if any(marker in line for marker in ("DEV STORY WORLD:", "DEV GUARD RELEASE", "OPENING MENU:", "OPENING WICK CUT:", "MISSION CLOCK:", "DAILY ERRANDS:", "EXPANDED ERRANDS:", "FOCUSED_GRIP", "PLAYER SAFETY:", "DELIVERY PARKING:", "DELIVERY_GROUND", "DELIVERY_SUPPORT_DIAGNOSTIC", "DELIVERY_CAST_DIAGNOSTIC", "STORY_TEST_QUIT_BEGIN", "STORY_TEST_RETIRED_DRAWABLES")):
                        print(line, flush=True)
                if args.review_seconds:
                    print("REVIEW_READY " + temporary, flush=True)
                    time.sleep(args.review_seconds)
            return 0 if passed else 1
        finally:
            shutil.rmtree(checks.user_data_directory(directory.name), ignore_errors=True)
            for key, value in previous.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value


if __name__ == "__main__":
    raise SystemExit(main())
