"""Actual Godot skin and morph contact check; generated surfaces are disposable."""
import os, subprocess, tempfile, argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
BLENDER='/Applications/Blender.app/Contents/MacOS/Blender'
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--layers',action='store_true',help='Also audit blouse/pallu crossings on the same native snapshots')
    args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='tlm_river_contact_') as folder:
        env=dict(os.environ,TLM_RIVER_TEST_OUTPUT=folder)
        commands=[
            [GODOT,'--headless','--path',str(ROOT),'--log-file',str(Path(folder)/'native.log'),'--script','res://tools/characters/export_river_test_surfaces.gd'],
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_river_native_contact.py'),'--',folder],
        ]
        if args.layers:commands.extend([
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/validate_river_layer_checker.py')],
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_river_layers.py'),'--',folder],
        ])
        failed=False
        for index,command in enumerate(commands):
            result=subprocess.run(command,cwd=ROOT,env=env,text=True,capture_output=True,timeout=600)
            output=result.stdout+result.stderr
            for line in output.splitlines():
                if line.startswith(('RIVER_NATIVE_SURFACES','NATIVE_CONTACT','RIVER_LAYER_CHECKER','RIVER_LAYER_CONTACT')):print(line,flush=True)
            if result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output:
                if not any(label in output for label in ['NATIVE_CONTACT','RIVER_LAYER_CONTACT']):print('\n'.join(output.splitlines()[-12:]))
                if index==0:return 1 # Later checks require a complete native export.
                failed=True
    return 1 if failed else 0
if __name__=='__main__':raise SystemExit(main())
