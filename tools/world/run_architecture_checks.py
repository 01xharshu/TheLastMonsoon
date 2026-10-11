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
            for name in names or ["crime_perception", "architecture_boundaries"]:
                if not name.replace("_", "").isalnum():
                    raise ValueError("Invalid check name")
                passed = checks.run_check(binary, project, directory, name.upper(),
                                         ["--script", "res://tools/world/validate_" + name + ".gd"], 240,native=native) and passed
                log=directory/(name.upper()+".log")
                if log.exists():
                    for line in log.read_text(errors="replace").splitlines():
                        if line.startswith(("ARCHITECTURE ","ARCHITECTURE BOUNDARIES ","ARCHITECTURE SERVICES ","ARCHITECTURE NAVIGATION ","REGION PRESENTATION ","CRIME PERCEPTION ","RUNTIME OPTIMISATION ")):
                            print(line,flush=True)
            return 0 if passed else 1
        finally:
            shutil.rmtree(checks.user_data_directory(directory.name), ignore_errors=True)

if __name__ == "__main__":
    raise SystemExit(main())
