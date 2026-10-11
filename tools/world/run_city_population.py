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
 parser.add_argument("--diagnose-import", action="store_true", help="Include verbose asset context when diagnosing an import failure")
 parser.add_argument("--city-budget", action="store_true", help="Measure populated city frame times at Medium using native timing")
 parser.add_argument("--passenger", action="store_true")
 parser.add_argument("--budget", action="store_true",help="Measure public passenger tiers in the actual native world at Medium")
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
   import_args=["--import","--verbose"] if args.diagnose_import else ["--import"]
   if not checks.run_check(binary,project,directory,"IMPORT",import_args,240):
    lines=(directory/"IMPORT.log").read_text().splitlines()
    for index,line in enumerate(lines):
     if line.startswith("ERROR:"):
      print("First import failure context:\n"+"\n".join(lines[max(0,index-25):index+3]),flush=True);break
    return 1
   movement_passed=True
   if args.city_budget:
    movement_passed=checks.run_check(binary,project,directory,"CITY_MOVEMENT",["--fixed-fps","20","--script","res://tools/world/validate_city_route_population.gd"],300)
    if not movement_passed:
     print("Native budget skipped until movement passes",flush=True)
     return 1
   script="tools/world/validate_city_population_budget.gd" if args.city_budget else "tools/horses/validate_public_cart_budget.gd" if args.budget else ("tools/horses/validate_public_passenger_cart.gd" if args.passenger else "tools/world/validate_city_route_population.gd")
   command=["--script","res://"+script] if args.city_budget else ["--fixed-fps","20","--script","res://"+script]
   if args.review:command += ["--","--output="+str(directory)]
   passed=checks.run_check(binary,project,directory,"PUBLIC_CART" if args.passenger or args.budget else "CITY_POPULATION",command,420 if args.city_budget else 360 if args.budget else 300,native=args.native or args.city_budget)
   if args.city_budget:
    for line in (directory/"CITY_POPULATION.log").read_text().splitlines():
     if line.startswith("CITY_NATIVE_BUDGET "):print(line,flush=True)
   passed=passed and movement_passed
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
