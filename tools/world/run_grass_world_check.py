"""Native populated-world grass smoke with isolated userdata and disposable logs."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"


def main():
    with tempfile.TemporaryDirectory(prefix="tlm-grass-world-") as temporary:
        directory = Path(temporary)
        project = directory / "project"
        project.mkdir()
        userdata = Path.home() / "Library/Application Support" / directory.name
        try:
            for entry in ROOT.iterdir():
                if entry.name not in (".git", "project.godot"):
                    (project / entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
            source = (ROOT / "project.godot").read_text()
            source = source.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + directory.name + '"', 1)
            (project / "project.godot").write_text(source)
            environment = os.environ.copy()
            environment["TLM_EXPECT_USER_DATA"] = str(userdata)
            result = subprocess.run(
                [GODOT, "--path", str(project), "--rendering-driver", "metal",
                 "--resolution", "1280x720", "--disable-vsync", "--log-file", str(directory / "engine.log"),
                 "--script", "res://tools/world/validate_grass_world.gd"],
                env=environment, timeout=360,
            )
            log = (directory / "engine.log").read_text()
            errors = any(marker in log for marker in ("SCRIPT ERROR:", "SHADER ERROR:", "ERROR:"))
            return result.returncode or int(errors or "GRASS WORLD PASS:" not in log)
        finally:
            shutil.rmtree(userdata, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
