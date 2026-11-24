"""Compare the shipped and candidate porter in disposable native worlds."""
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
MODEL = Path("characters/npcs/street_residents/workman_03.glb")
SOURCE = Path("WorkingAssets/NPCs/indian_street_variants/workman_03/workman_03.blend")
REVIEW = "res://tools/world/review_grain_delivery_world.gd"


def run(command, directory, name, timeout, env=None):
    log_path = directory / (name + ".log")
    with log_path.open("w") as log:
        process = subprocess.run(command, cwd=ROOT, env=env, stdout=log,
                                 stderr=subprocess.STDOUT, timeout=timeout)
    output = log_path.read_text(errors="replace")
    if process.returncode:
        raise RuntimeError(f"{name} exited {process.returncode}:\n{output[-5000:]}")
    if "SCRIPT ERROR" in output or "Parse Error" in output:
        raise RuntimeError(f"{name} reported script errors:\n{output[-5000:]}")
    for line in output.splitlines():
        if line.startswith(("GRAIN_NATIVE:", "GRAIN_WAIST_REVIEW")):
            print(line, flush=True)


def review(project, output):
    output.mkdir()
    env = dict(os.environ, TLM_GRAIN_REVIEW_DIR=str(output), TLM_GRAIN_WAIST_REVIEW="1")
    run([GODOT, "--path", str(project), "--rendering-driver", "metal",
         "--resolution", "1280x720", "--log-file", str(output / "engine.log"),
         "--script", REVIEW], output, "review", 350, env)


def main():
    sys.path.insert(0, str(ROOT / "tools/maintenance"))
    from check_game import copy_stable_file

    with tempfile.TemporaryDirectory(prefix="tlm-grain-waist-") as name:
        directory = Path(name)
        print(f"Temporary waist review: {directory}", flush=True)
        project = directory / "project"
        shutil.copytree(ROOT, project, copy_function=copy_stable_file,
                        ignore=shutil.ignore_patterns(".git", ".godot", "WorkingAssets",
                                                      "__pycache__", "node_modules"))
        shutil.copytree(ROOT / ".godot/imported", project / ".godot/imported",
                        copy_function=copy_stable_file)
        for cache_file in ("global_script_class_cache.cfg", "uid_cache.bin"):
            copy_stable_file(ROOT / ".godot" / cache_file, project / ".godot" / cache_file)
        preview = directory / "preview.glb"
        run([BLENDER, "-b", str(ROOT / SOURCE), "--python-exit-code", "1",
             "--python", str(ROOT / "tools/characters/refit_grain_porter_waist.py"),
             "--", "--candidate", str(directory / "preview.blend"),
             "--preview-glb", str(preview)], directory, "export", 120)
        review(project, directory / "baseline")
        shutil.copyfile(preview, project / MODEL)
        run([GODOT, "--headless", "--path", str(project), "--log-file",
             str(directory / "import-engine.log"), "--import"], directory, "import", 600)
        review(project, directory / "candidate")
        print("Both reviews finished. Create reviewed in the temporary directory after inspection.",
              flush=True)
        deadline = time.monotonic() + 180
        while not (directory / "reviewed").exists() and time.monotonic() < deadline:
            time.sleep(1)


if __name__ == "__main__":
    main()
