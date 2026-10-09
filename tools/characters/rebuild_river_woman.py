"""Rebuild retained river assets while removing all disposable build logs."""
import subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
BLENDER='/Applications/Blender.app/Contents/MacOS/Blender'
def main():
    with tempfile.TemporaryDirectory(prefix='tlm_river_build_') as folder:
        commands=[
            [GODOT,'--headless','--path',str(ROOT),'--log-file',str(Path(folder)/'poses.log'),'--script','res://tools/characters/export_river_poses.gd'],
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/build_river_woman_candidate.py')],
            [GODOT,'--headless','--editor','--path',str(ROOT),'--log-file',str(Path(folder)/'import.log'),'--import'],
        ]
        for command in commands:
            result=subprocess.run(command,cwd=ROOT,text=True,capture_output=True,timeout=1800)
            output=result.stdout+result.stderr
            for line in output.splitlines():
                if line.startswith(('RIVER_POSES','RIVER_SOURCE','RIVER_LOCAL_FIT_LIMIT')):print(line,flush=True)
            if result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output:
                print('\n'.join(output.splitlines()[-20:]));return 1
    print('River source and runtime rebuilt; contact and visual approval remain separate.')
    return 0
if __name__=='__main__':raise SystemExit(main())
