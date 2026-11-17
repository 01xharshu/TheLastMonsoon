"""Run isolated New Journey, disk Continue, and standalone fort checks."""
from pathlib import Path
import os, shutil, subprocess, tempfile
ROOT = Path(__file__).resolve().parents[2]
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'
def main():
    with tempfile.TemporaryDirectory(prefix='tlm-hideout-') as folder:
        directory = Path(folder); project = directory/'project'; project.mkdir()
        userdata = Path.home()/'Library/Application Support'/directory.name
        try:
            for entry in ROOT.iterdir():
                if entry.name not in ('.git', 'project.godot'):
                    (project/entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
            (project/'project.godot').write_text((ROOT/'project.godot').read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+directory.name+'"', 1))
            for script, phase in [('validate_hideout_secrecy.gd','0'),('validate_hideout_secrecy.gd','1'),('validate_fort_encounter.gd','0')]:
                env = os.environ.copy(); env['TLM_HIDEOUT_CONTINUE']=phase
                try:
                    result = subprocess.run([GODOT,'--headless','--path',str(project),'--script','res://tools/world/'+script],capture_output=True,text=True,env=env,timeout=300)
                except subprocess.TimeoutExpired:
                    print(script,phase,'TIMEOUT',flush=True); return 1
                output=result.stdout+result.stderr
                print('\n'.join(line for line in output.splitlines() if any(key in line for key in ('HIDEOUT SECRECY','FORT ENCOUNTER','ERROR','SCRIPT',' at:'))),flush=True)
                marker='FORT ENCOUNTER PASS' if script=='validate_fort_encounter.gd' else 'HIDEOUT SECRECY '+('CONTINUE' if phase=='1' else 'NEW')+': PASS'
                if result.returncode or 'ERROR:' in output or marker not in output:
                    print(script,phase,'FAILED exit',result.returncode,flush=True); return 1
            return 0
        finally:shutil.rmtree(userdata,ignore_errors=True)
if __name__=='__main__':raise SystemExit(main())
