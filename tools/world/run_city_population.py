"""Check populated-world traffic using a disposable snapshot; no outputs retained."""
import argparse, importlib.util, shutil, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("game_checks", ROOT/"tools/maintenance/check_game.py")
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)
def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument("--native", action="store_true")
 args=parser.parse_args()
 with tempfile.TemporaryDirectory(prefix="tlm-game-check-traffic-") as folder:
  directory=Path(folder); project=directory/"project"
  shutil.copytree(ROOT,project,copy_function=checks.copy_stable_file,ignore=shutil.ignore_patterns(".git",".godot","WorkingAssets","__pycache__","node_modules",".next"))
  config=project/"project.godot"
  config.write_text(config.read_text().replace("[application]", "[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=\""+directory.name+"\""))
  try:
   binary=shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
   if not checks.run_check(binary,project,directory,"IMPORT",["--import"],240):return 1
   return 0 if checks.run_check(binary,project,directory,"CITY_POPULATION",["--fixed-fps","20","--script","res://tools/world/validate_city_route_population.gd"],300,native=args.native) else 1
  finally:shutil.rmtree(checks.user_data_directory(directory.name),ignore_errors=True)
if __name__ == "__main__":raise SystemExit(main())
