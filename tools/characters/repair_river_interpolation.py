"""Repair native river blends; all generated geometry and logs are temporary."""
import os,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
BLENDER='/Applications/Blender.app/Contents/MacOS/Blender'
def main():
 with tempfile.TemporaryDirectory(prefix='tlm_river_repair_') as folder:
  env=dict(os.environ,TLM_RIVER_TEST_OUTPUT=folder)
  commands=[
   [GODOT,'--headless','--path',str(ROOT),'--log-file',str(Path(folder)/'surfaces.log'),'--script','res://tools/characters/export_river_test_surfaces.gd'],
   [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/refine_river_interpolation.py'),'--',folder],
   [GODOT,'--headless','--editor','--path',str(ROOT),'--log-file',str(Path(folder)/'import.log'),'--import'],
  ]
  for command in commands:
   result=subprocess.run(command,cwd=ROOT,env=env,text=True,capture_output=True,timeout=1800)
   output=result.stdout+result.stderr
   for line in output.splitlines():
    if line.startswith(('RIVER_NATIVE','RIVER_INTERPOLATION','RIVER_LOCAL_FIT_LIMIT','RIVER_SOURCE')):print(line,flush=True)
   if result.returncode or 'SCRIPT ERROR:' in output or '\nERROR:' in output:
    print('\n'.join(output.splitlines()[-20:]));return 1
 return subprocess.call(['python3',str(ROOT/'tools/characters/check_river_cloth.py')],cwd=ROOT)
if __name__=='__main__':raise SystemExit(main())
