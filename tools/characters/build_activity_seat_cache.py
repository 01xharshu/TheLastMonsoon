"""Rebuild source-verified activity seat profiles using a disposable Godot project."""
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
TARGET = ROOT / "characters/npcs/activity_people/seat_profiles.gd"

with tempfile.TemporaryDirectory(prefix="tlm-seat-build-") as folder:
    directory = Path(folder)
    project = directory / "project"
    project.mkdir()
    user_data = Path.home() / "Library/Application Support" / directory.name
    try:
        for item in ROOT.iterdir():
            if item.name not in (".git", "project.godot"):
                (project / item.name).symlink_to(item, target_is_directory=item.is_dir())
        config = (ROOT / "project.godot").read_text()
        config = config.replace(
            "[application]",
            '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'
            + directory.name + '"',
            1,
        )
        (project / "project.godot").write_text(config)
        output = directory / "profiles.json"
        command = [
            GODOT, "--headless", "--path", str(project), "--log-file", str(directory / "engine.log"),
            "--script", "res://tools/characters/bake_activity_seat_cache.gd",
            "--", str(output), "--rebuild",
        ]
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=120)
        print(result.stdout)
        if result.returncode or "SCRIPT ERROR" in result.stdout or "\nERROR:" in result.stdout:
            raise SystemExit(1)
        profiles = json.loads(output.read_text())
        if len(profiles) != 5 or any(not profile["samples"] for profile in profiles.values()):
            raise RuntimeError("Seat profiles do not contain the expected fitted bodies")
        replacement = directory / "seat_profiles.gd"
        replacement.write_text(
            "extends RefCounted\n## Baked by tools/characters/build_activity_seat_cache.py.\n"
            + "const PROFILES = " + json.dumps(profiles, indent=2) + "\n"
        )
        shutil.copyfile(replacement, TARGET)
    finally:
        shutil.rmtree(user_data, ignore_errors=True)
