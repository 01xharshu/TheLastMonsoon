"""Rebuild retained river assets while removing all disposable build logs."""
import os,subprocess,tempfile,argparse,time,signal
from collections import deque
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
BLENDER='/Applications/Blender.app/Contents/MacOS/Blender'
PREFIXES=('RIVER_POSES','RIVER_SOURCE','RIVER_LOCAL_FIT_LIMIT','RIVER_NATIVE','RIVER_INTERPOLATION','RIVER_UPPER_FAIRING','RIVER_UPPER_SEAMS')
def run_step(command,env,log_path):
    tail=deque(maxlen=20);pending='';failed=False
    with log_path.open('w') as sink, log_path.open('r') as reader:
        process=subprocess.Popen(command,cwd=ROOT,env=env,text=True,stdout=sink,stderr=subprocess.STDOUT)
        deadline=time.monotonic()+1800
        try:
            while True:
                pending+=reader.read()
                while '\n' in pending:
                    line,pending=pending.split('\n',1);tail.append(line)
                    if line.startswith(PREFIXES):print(line,flush=True)
                    failed=failed or 'SCRIPT ERROR:' in line or line.startswith('ERROR:')
                if process.poll() is not None:
                    # Drain output written between the last read and exit.
                    remainder=reader.read()
                    if remainder:
                        pending+=remainder;continue
                    break
                if time.monotonic()>deadline:
                    raise subprocess.TimeoutExpired(command,1800)
                time.sleep(.2)
            if pending:tail.append(pending)
            if process.returncode or failed:
                print('\n'.join(tail),flush=True);return False
            return True
        finally:
            if process.poll() is None:process.kill()
            process.wait()

def main():
    def interrupted(_signal,_frame):raise KeyboardInterrupt
    signal.signal(signal.SIGTERM,interrupted)
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fit-current',action='store_true',help='Fit the current runtime garment topology without replacing it')
    parser.add_argument('--fair-upper',action='store_true',help='Smooth inherited upper-cloth folds before current-topology fitting')
    parser.add_argument('--fair-posed-upper',action='store_true',help='Smooth rendered upper-cloth poses while preserving their skin compensation')
    parser.add_argument('--sew-upper',action='store_true',help='Regularize the existing waist and sleeve boundary loops in authored poses')
    args=parser.parse_args()
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
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/rebuild_river_pallu.py')],
            [GODOT,'--headless','--editor','--path',str(ROOT),'--log-file',str(Path(folder)/'layer_import.log'),'--import'],
        ]
        # The pallu builder changes the runtime topology. Its inherited keys
        # need fitting on that topology, after it has been imported by Godot.
        final_fit=[
            [GODOT,'--headless','--path',str(ROOT),'--log-file',str(Path(folder)/'retopology_surfaces.log'),'--script','res://tools/characters/export_river_test_surfaces.gd'],
            [BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/refine_river_interpolation.py'),'--',folder,'--finish-upper','--upper-only'],
            [GODOT,'--headless','--editor','--path',str(ROOT),'--log-file',str(Path(folder)/'retopology_import.log'),'--import'],
        ]
        if args.fair_upper:final_fit[1].append('--fair-upper')
        if args.fair_posed_upper:final_fit[1].append('--fair-posed-upper')
        if args.sew_upper:final_fit[1].append('--sew-upper')
        current_import=[GODOT,'--headless','--editor','--path',str(ROOT),'--log-file',str(Path(folder)/'current_import.log'),'--import']
        commands=[current_import]+final_fit if args.fit_current else commands+final_fit
        for index,command in enumerate(commands):
            if not run_step(command,env,Path(folder)/('step_%02d.log'%index)):return 1
    print('River source and runtime rebuilt; contact and visual approval remain separate.')
    return 0
if __name__=='__main__':raise SystemExit(main())
