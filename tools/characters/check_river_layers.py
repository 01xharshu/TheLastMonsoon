"""Native foundation/blouse/pallu crossing check with automatic disposable-output cleanup."""
import os,subprocess,tempfile,argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--all",action="store_true",help="Audit all 207 native intermediate poses");parser.add_argument("--repair",action="store_true");parser.add_argument("--align",action="store_true");args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='tlm_river_layers_') as folder:
        env=dict(os.environ,TLM_RIVER_TEST_OUTPUT=folder)
        if not args.all:env['TLM_RIVER_EXACT']='1'
        else:env.pop('TLM_RIVER_EXACT',None)
        commands=[['/Applications/Godot.app/Contents/MacOS/Godot','--headless','--path',str(ROOT),'--log-file',str(Path(folder)/'native.log'),'--script','res://tools/characters/export_river_test_surfaces.gd'],['/Applications/Blender.app/Contents/MacOS/Blender','--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_river_layers.py'),'--',folder]]
        if args.align:
            commands[1]=["/Applications/Blender.app/Contents/MacOS/Blender","--background","--python-exit-code","1","--python",str(ROOT/"tools/characters/refine_river_interpolation.py"),"--",folder,"--cloth-align-only"]
        if args.repair:
            commands=[
                ['/Applications/Blender.app/Contents/MacOS/Blender','--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/rebuild_river_pallu.py')],
                ['/Applications/Godot.app/Contents/MacOS/Godot','--headless','--editor','--path',str(ROOT),'--log-file',str(Path(folder)/'import.log'),'--import'],
                commands[0],commands[1],
            ]
        commands.insert(0,["/Applications/Blender.app/Contents/MacOS/Blender","--background","--python-exit-code","1","--python",str(ROOT/"tools/characters/validate_river_layer_checker.py")])
        for command in commands:
            result=subprocess.run(command,cwd=ROOT,env=env,text=True,capture_output=True,timeout=600)
            output=result.stdout+result.stderr
            for line in output.splitlines():
                if line.startswith(('RIVER_NATIVE_SURFACES','RIVER_LAYER_CONTACT','RIVER_INTERPOLATION_SWEEP','RIVER_NATIVE_ALIGNMENT_M','RIVER_NATIVE_CLOTH_ALIGNMENT','RIVER_SOURCE_LAYER_REMAINING','RIVER_LAYER_CHECKER','RIVER_SOURCE','RIVER_PALLU_REBUILT')):print(line,flush=True)
            if result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output:
                if 'RIVER_LAYER_CONTACT' not in output:print('\n'.join(output.splitlines()[-12:]))
                return 1
    return 0
if __name__=='__main__':raise SystemExit(main())
