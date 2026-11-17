"""Disposable actual-world map and physical player exploration check."""
from pathlib import Path
import os, shutil, subprocess, tempfile, time
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
def main():
    with tempfile.TemporaryDirectory(prefix='tlm-explore-') as folder:
        directory=Path(folder);project=directory/'project';project.mkdir()
        userdata=Path.home()/'Library/Application Support'/directory.name
        try:
            for entry in ROOT.iterdir():
                if entry.name not in ('.git','project.godot'):(project/entry.name).symlink_to(entry,target_is_directory=entry.is_dir())
            (project/'project.godot').write_text((ROOT/'project.godot').read_text().replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+directory.name+'"',1))
            log=directory/'engine.log'
            with log.open('w') as stream:
                process=subprocess.Popen([GODOT,'--headless','--path',str(project),'--script','res://tools/world/validate_institution_exploration.gd'],stdout=stream,stderr=subprocess.STDOUT)
                try:
                    started=time.monotonic()
                    while process.poll() is None:
                        if time.monotonic()-started>480 or 'SCRIPT ERROR:' in log.read_text():process.terminate();break
                        time.sleep(.5)
                    process.wait(timeout=15)
                finally:
                    if process.poll() is None:process.kill();process.wait()
            output=log.read_text()
            print('\n'.join(line for line in output.splitlines() if any(word in line for word in ['EXPLORE','EXPLORATION','ERROR',' at:','[0]','[1]'])),flush=True)
            return process.returncode or int('ERROR:' in output or 'INSTITUTION EXPLORATION: PASS' not in output)
        finally:shutil.rmtree(userdata,ignore_errors=True)
if __name__=='__main__':raise SystemExit(main())
