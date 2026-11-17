"""Check adult secondary motion using private saves and disposable diagnostics."""
import os, shutil, subprocess, tempfile, argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--asset',action='store_true');args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='tlm-adult-secondary-') as folder:
        directory=Path(folder);project=directory/'project';project.mkdir()
        userdata=Path.home()/'Library/Application Support'/directory.name
        try:
            for item in ROOT.iterdir():
                if item.name not in ('.git','project.godot'):(project/item.name).symlink_to(item,target_is_directory=item.is_dir())
            config=(ROOT/'project.godot').read_text().replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+directory.name+'"',1)
            (project/'project.godot').write_text(config)
            env=os.environ.copy()
            if args.asset:env['TLM_RIVER_SECONDARY']='1';env.pop('TLM_RIVER_PROFILE',None)
            script='validate_adult_secondary_asset.gd' if args.asset else 'validate_adult_secondary_motion.gd'
            result=subprocess.run(['/Applications/Godot.app/Contents/MacOS/Godot','--headless','--path',str(project),'--log-file',str(directory/'engine.log'),'--script','res://tools/characters/'+script],cwd=ROOT,env=env,text=True,capture_output=True,timeout=60)
            output=result.stdout+result.stderr
            for line in output.splitlines():
                if line.startswith(('ADULT_SECONDARY_MOTION ','ADULT_SECONDARY_ASSET ','SECONDARY_COHERENCE ')) or 'ERROR' in line or 'res://' in line:print(line)
            return int(result.returncode!=0 or '"passed":true' not in output or 'SCRIPT ERROR:' in output)
        finally:shutil.rmtree(userdata,ignore_errors=True)
if __name__=='__main__':raise SystemExit(main())
