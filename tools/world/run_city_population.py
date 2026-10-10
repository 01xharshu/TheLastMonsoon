"""Check populated-world traffic using a disposable snapshot; no outputs retained."""
import argparse, importlib.util, shutil, signal, sys, tempfile
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("game_checks", ROOT/"tools/maintenance/check_game.py")
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)
def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument("--native", action="store_true")
 parser.add_argument("--passenger", action="store_true")
 parser.add_argument("--review", action="store_true")
 parser.add_argument("--opening", action="store_true",help="Also check the integrated opening cart passage in this snapshot")
 args=parser.parse_args()
 for sig in (signal.SIGINT,signal.SIGTERM):signal.signal(sig,lambda *_:(_ for _ in ()).throw(KeyboardInterrupt()))
 with tempfile.TemporaryDirectory(prefix="tlm-game-check-traffic-") as folder:
  directory=Path(folder); project=directory/"project"
  shutil.copytree(ROOT,project,copy_function=checks.copy_stable_file,ignore=shutil.ignore_patterns(".git",".godot","WorkingAssets","__pycache__","node_modules",".next"))
  config=project/"project.godot"
  config.write_text(config.read_text().replace("[application]", "[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=\""+directory.name+"\""))
  try:
   binary=shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
   if not checks.run_check(binary,project,directory,"IMPORT",["--import"],240):return 1
   script="tools/horses/validate_public_passenger_cart.gd" if args.passenger else "tools/world/validate_city_route_population.gd"
   command=["--fixed-fps","20","--script","res://"+script]
   if args.review:command += ["--","--output="+str(directory)]
   passed=checks.run_check(binary,project,directory,"PUBLIC_CART" if args.passenger else "CITY_POPULATION",command,300,native=args.native)
   if args.opening:
    passed=checks.run_check(binary,project,directory,"OPENING_CART",["--fixed-fps","20","--script","res://tools/world/validate_opening_cart_passage.gd"],300) and passed
   review_image=directory/("passenger_cart.png" if args.passenger else "road_traffic.png")
   if args.review and review_image.exists():
    print("Review image: "+str(review_image),flush=True)
    try:input("Press Enter after transient visual review; the directory will be deleted.\n")
    except EOFError:pass
   return 0 if passed else 1
  finally:shutil.rmtree(checks.user_data_directory(directory.name),ignore_errors=True)
if __name__ == "__main__":raise SystemExit(main())
