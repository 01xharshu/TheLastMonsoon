"""Run integration regressions in a disposable project and user-data directory."""
import importlib.util
import os
import shutil
import signal
import sys
import tempfile
import subprocess
import time
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("game_checks", ROOT / "tools/maintenance/check_game.py")
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)

def main():
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    with tempfile.TemporaryDirectory(prefix="tlm-architecture-") as folder:
        directory = Path(folder)
        project = directory / "project"
        shutil.copytree(ROOT, project, copy_function=checks.copy_stable_file,
                        ignore=shutil.ignore_patterns(".git", ".godot", "WorkingAssets", "__pycache__", "node_modules", ".next"))
        config = project / "project.godot"
        config.write_text(config.read_text().replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + directory.name + '"'))
        os.environ["TLM_SAVE_TEST_DIR"]=str(directory)
        try:
            binary = shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
            names=sys.argv[1:]
            trace_position="--trace-player-position" in names
            if trace_position:
                names.remove("--trace-player-position")
                # Instrument only the disposable copy. Production source and
                # normal checks incur no transform notifications or tracing.
                player_script=project/"player/player_controller.gd"
                source=player_script.read_text()
                if "func _notification(" in source:
                    raise RuntimeError("Player already has a notification handler; update the trace adapter safely")
                source=source.replace("func _ready() -> void:","func _ready() -> void:\n\tset_notify_transform(true)",1)
                source=source.replace("move_and_slide()", "_station_trace_slide()")
                source+='''
func _station_trace_slide() -> bool:
    var before:=global_position
    var query:=PhysicsShapeQueryParameters3D.new()
    query.shape=$CollisionShape3D.shape
    query.transform=$CollisionShape3D.global_transform
    query.collision_mask=collision_mask
    query.exclude=[get_rid()]
    var contacts:Array=[]
    if has_meta("station_position_trace"):
        contacts=get_world_3d().direct_space_state.intersect_shape(query,32)
    var moved:=move_and_slide()
    if has_meta("station_position_trace") and global_position.distance_to(before)>.16:
        print("ARREST POSITION WRITER move_and_slide ",before," -> ",global_position," velocity ",velocity," platform ",get_platform_velocity()," overlaps ",contacts," stack ",get_stack())
    return moved

func _notification(what: int) -> void:
    if what!=NOTIFICATION_TRANSFORM_CHANGED or not is_inside_tree() or not has_meta("station_position_trace"): return
    var previous:Vector3=get_meta("station_position_trace")
    var at:=global_position
    set_meta("station_position_trace",at)
    if at.distance_to(previous)>.16:
        print("ARREST POSITION WRITER ",previous," -> ",at," detention ",get_node("DetentionComponent").mode," flags ",get_meta("paired_combat",false)," stack ",get_stack())
'''.replace("    ","\t")
                player_script.write_text(source)
            native="--native" in names
            if native:
                names.remove("--native")
                deadline=time.monotonic()+180
                announced=False
                while True:
                    result=subprocess.run(["/usr/bin/pgrep","-fl","Godot"],capture_output=True,text=True,check=False)
                    occupied=any("/Applications/Godot.app/Contents/MacOS/Godot " in line and "--headless" not in line for line in result.stdout.splitlines())
                    if not occupied:break
                    if not announced:
                        print("Waiting for the active native renderer; no other job will be interrupted.",flush=True)
                        announced=True
                    if time.monotonic()>=deadline:
                        print("Native renderer remained occupied; no native check launched.",flush=True)
                        return 2
                    time.sleep(3)
            cached="--cached" in names
            if cached:
                names.remove("--cached")
                cache=project/".godot"
                cache.mkdir()
                shutil.copytree(ROOT/".godot/imported",cache/"imported",copy_function=checks.copy_stable_file)
                shutil.copy2(ROOT/".godot/global_script_class_cache.cfg",cache/"global_script_class_cache.cfg")
                shutil.copy2(ROOT/".godot/uid_cache.bin",cache/"uid_cache.bin")
                print("Using copied current import cache; this does not validate fresh import.",flush=True)
                passed=True
            else:
                passed=checks.run_check(binary, project, directory, "IMPORT", ["--import"], 300)
            if trace_position:
                probe=project/"tools/world/station_trace_parse.gd"
                probe.write_text('extends SceneTree\nfunc _initialize() -> void: verify.call_deferred()\nfunc verify() -> void:\n\tvar script:Script=load("res://player/player_controller.gd")\n\troot.get_node("SaveManager").quit_game(0 if script!=null and script.can_instantiate() else 1)\n')
                parsed=checks.run_check(binary,project,directory,"TRACE_PARSE",["--script","res://tools/world/station_trace_parse.gd"],30)
                if not parsed:return 1
            for name in names or ["crime_perception", "architecture_boundaries"]:
                if not name.replace("_", "").isalnum():
                    raise ValueError("Invalid check name")
                arguments=(["res://tools/characters/validate_window_house.tscn"] if name=="window_house" else
                           ["--script","res://tools/characters/validate_window_single_press.gd"] if name=="window_single_press" else
                           ["--script", "res://tools/world/validate_" + name + ".gd"])
                passed = checks.run_check(binary, project, directory, name.upper(),arguments,240,native=native) and passed
                log=directory/(name.upper()+".log")
                if log.exists():
                    lines=log.read_text(errors="replace").splitlines()
                    if name=="police_arrest" and not any(line.startswith("POLICE ARREST PASS ") for line in lines):
                        print("POLICE ARREST incomplete or failed; no successful completion marker.",flush=True)
                        passed=False
                    marker={"contextual_jump":'"status":"PASS"',"window_house":"WINDOW HOUSE: PASS", "window_single_press":"WINDOW SINGLE PRESS: PASS"}.get(name)
                    if marker and not any(marker in line for line in lines):
                        print(name.upper()+" incomplete; no successful completion marker.",flush=True)
                        passed=False
                    for line in lines:
                        if line.startswith("STATION CONTACT "):print(line,flush=True)
                        if line.startswith(("WINDOW HOUSE: PASS","WINDOW SINGLE PRESS: PASS")):print(line,flush=True)
                        if line.startswith(("CONTEXTUAL JUMP ","ARCHITECTURE ","ARCHITECTURE BOUNDARIES ","ARCHITECTURE SERVICES ","ARCHITECTURE NAVIGATION ","REGION PRESENTATION ","CRIME PERCEPTION ","RUNTIME OPTIMISATION ","STATION NAVIGATION ","POLICE CUSTODY:","POLICE ARREST ","ARREST LARGE STEP ","ARREST BODY CONTACT ","ARREST STOP ","ARREST POSITION WRITER ")):
                            print(line,flush=True)
            return 0 if passed else 1
        finally:
            shutil.rmtree(checks.user_data_directory(directory.name), ignore_errors=True)

if __name__ == "__main__":
    raise SystemExit(main())
