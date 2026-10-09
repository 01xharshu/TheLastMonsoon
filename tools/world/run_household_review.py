"""Native household review with temporary output and guaranteed cleanup."""
import os,signal,subprocess,tempfile,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def interrupted(signum,frame):raise SystemExit(128+signum)
for sig in (signal.SIGINT,signal.SIGTERM):signal.signal(sig,interrupted)
with tempfile.TemporaryDirectory(prefix='tlm-household-review-') as folder:
    env=os.environ.copy();env['TLM_HOUSEHOLD_REVIEW_TEMP']=folder
    print('TEMP_REVIEW',folder,flush=True)
    process=subprocess.Popen(['/Applications/Godot.app/Contents/MacOS/Godot','--path',str(ROOT),'--fixed-fps','30']+(['--rendering-method','gl_compatibility'] if '--compatibility' in sys.argv else [])+['--script','tools/world/review_household_drape.gd']+(['--','--poses-only'] if '--poses-only' in sys.argv else []),cwd=ROOT,env=env)
    try:
        try:result=process.wait(timeout=180)
        except subprocess.TimeoutExpired:
            print("HOUSEHOLD_REVIEW_TIMEOUT: native review incomplete",flush=True);result=1
        if result==0 and '--poses-only' in sys.argv:
            print('TEMP_READY_FOR_INSPECTION',folder,flush=True)
            time.sleep(35)
    finally:
        if process.poll() is None:
            process.terminate()
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait()
raise SystemExit(result)
