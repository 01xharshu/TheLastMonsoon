"""Rebuild retained river assets while removing all disposable build logs."""
import os,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
BLENDER='/Applications/Blender.app/Contents/MacOS/Blender'
def main():
    with tempfile.TemporaryDirectory(prefix='tlm_river_build_') as folder:
        poses=str(Path(folder)/'poses.json')
        env=dict(os.environ,TLM_RIVER_POSE_OUTPUT=poses,TLM_RIVER_TEST_OUTPUT=folder)
        commands=[
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/build_river_woman_candidate.py')],
            [GODOT,'--headless','--editor','--path',str(ROOT),'--log-file',str(Path(folder)/'import.log'),'--import'],
            [GODOT,'--headless','--path',str(ROOT),'--log-file',str(Path(folder)/'poses.log'),'--script','res://tools/characters/export_river_poses.gd','--','--upper-fit'],
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/fit_river_upper_clothing.py'),'--',poses],
            [GODOT,'--headless','--editor','--path',str(ROOT),'--log-file',str(Path(folder)/'final_import.log'),'--import'],
            [GODOT,'--headless','--path',str(ROOT),'--log-file',str(Path(folder)/'surfaces.log'),'--script','res://tools/characters/export_river_test_surfaces.gd'],
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/refine_river_interpolation.py'),'--',folder],
            [GODOT,'--headless','--editor','--path',str(ROOT),'--log-file',str(Path(folder)/'refined_import.log'),'--import'],
            [GODOT,'--headless','--path',str(ROOT),'--log-file',str(Path(folder)/'foundation_surfaces.log'),'--script','res://tools/characters/export_river_test_surfaces.gd'],
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/refine_river_interpolation.py'),'--',folder,'--finish-upper'],
            [GODOT,'--headless','--editor','--path',str(ROOT),'--log-file',str(Path(folder)/'contact_import.log'),'--import'],
        ]
        for command in commands:
            result=subprocess.run(command,cwd=ROOT,env=env,text=True,capture_output=True,timeout=1800)
            output=result.stdout+result.stderr
            for line in output.splitlines():
                if line.startswith(('RIVER_POSES','RIVER_SOURCE','RIVER_LOCAL_FIT_LIMIT','RIVER_NATIVE','RIVER_INTERPOLATION')):print(line,flush=True)
            if result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output:
                print('\n'.join(output.splitlines()[-20:]));return 1
    print('River source and runtime rebuilt; contact and visual approval remain separate.')
    return 0
if __name__=='__main__':raise SystemExit(main())
