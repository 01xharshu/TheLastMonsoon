"""Run placed-role/save regression with OS-temp save data, removed on every exit."""
import os,signal,subprocess,tempfile,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def interrupted(signum,frame):raise SystemExit(128+signum)
for sig in (signal.SIGINT,signal.SIGTERM):signal.signal(sig,interrupted)
with tempfile.TemporaryDirectory(prefix='tlm-household-save-') as folder:
    env=os.environ.copy();env['TLM_HOUSEHOLD_SAVE_TEMP']=folder
    process=subprocess.Popen(['/Applications/Godot.app/Contents/MacOS/Godot']+([] if '--native' in sys.argv else ['--headless'])+['--fixed-fps','60','--path',str(ROOT),'--script','tools/world/validate_household_roles_world.gd'],cwd=ROOT,env=env)
    try:
        try:result=process.wait(timeout=240)
        except subprocess.TimeoutExpired:print('HOUSEHOLD WORLD CHECK TIMEOUT');result=1
    finally:
        if process.poll() is None:
            process.terminate()
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait()
raise SystemExit(result)
