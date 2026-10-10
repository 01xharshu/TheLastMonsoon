"""Isolated population checks; all imports, logs, saves and images die with the temporary copy."""
import argparse
import importlib.util
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('population_checks', ROOT/'tools/maintenance/check_game.py')
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)

def native_jobs():
    result = subprocess.run(['ps','-axo','command'], capture_output=True, text=True)
    return [line for line in result.stdout.splitlines() if '/Godot ' in line]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--fixture', action='store_true')
    parser.add_argument('--budget', action='store_true')
    args = parser.parse_args()
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    with tempfile.TemporaryDirectory(prefix='tlm-population-expansion-') as folder:
        output = Path(folder); project = output/'project'
        shutil.copytree(ROOT, project, copy_function=checks.copy_stable_file,
                        ignore=shutil.ignore_patterns('.git','WorkingAssets','__pycache__','node_modules','.next'))
        config = project/'project.godot'
        config.write_text(config.read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+output.name+'"'))
        binary = shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot'
        try:
            if not checks.run_check(binary,project,output,'IMPORT',['--import'],240): return 1
            if args.native:
                deadline = time.monotonic()+600
                announced = False
                while native_jobs():
                    if not announced:
                        print('Waiting for the existing native renderer to finish; no other chat is interrupted.',flush=True)
                        announced = True
                    if time.monotonic()>deadline: raise RuntimeError('Native renderer still occupied; no uncontended measurement available')
                    time.sleep(5)
            script = 'validate_population_budget.gd' if args.budget else ('validate_population_crowd.gd' if args.fixture else 'validate_population_expansion.gd')
            command = ['--script','res://tools/world/'+script]
            if not args.native: command = ['--fixed-fps','30',*command]
            # Keep full-world output compact while exposing our verification summary.
            original = checks.run_check
            passed = original(binary,project,output,'CITY_POPULATION',command,480,native=args.native)
            logfile=output/'CITY_POPULATION.log'
            if logfile.exists():
                for line in logfile.read_text(errors='replace').splitlines():
                    if line.startswith(('POPULATION EXPANSION','CROWD RESULT','POPULATION PROFILE','POPULATION BUDGET')):print(line,flush=True)
            return 0 if passed else 1
        finally:
            shutil.rmtree(checks.user_data_directory(output.name),ignore_errors=True)
if __name__ == '__main__':raise SystemExit(main())
