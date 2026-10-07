"""Reusable river checks; disposable media is always cleaned, including on failure."""
import argparse, json, os, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ENGINE='/Applications/Godot.app/Contents/MacOS/Godot'

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--render',action='store_true',help='Check focused Metal capture without retaining images')
    args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='tlm_river_check_') as folder:
        env=os.environ.copy();env['TLM_RIVER_TEST_OUTPUT']=folder
        scripts=['tools/characters/validate_river_routine.gd','tools/world/validate_women_river.gd']
        if args.render:scripts.append('tools/world/capture_women_river.gd')
        for script in scripts:
            command=[ENGINE,'--path',str(ROOT),'--script','res://'+script]
            if 'capture_' in script:command+=['--','--focused']
            else:command.insert(1,'--headless')
            result=subprocess.run(command,cwd=ROOT,env=env,text=True,capture_output=True,timeout=120)
            output=result.stdout+result.stderr
            failed=result.returncode!=0 or 'SCRIPT ERROR:' in output or '\nERROR:' in output
            for line in output.splitlines():
                if line.startswith(('RIVER_ROUTINE ','RIVER_WORLD ')):
                    data=json.loads(line.split(' ',1)[1]);print(script, 'PASS' if data['passed'] else 'FAIL',
                        'issues=',data['issues'], 'ankle_m=',data.get('max_ankle_m'), 'wrist_m=',data.get('max_hand_m'))
                    failed=failed or not data['passed']
            if failed:
                print('\n'.join(output.splitlines()[-12:]));return 1
            if 'capture_' in script:print('Focused Metal rendering completed; temporary images discarded.')
    return 0
if __name__=='__main__':raise SystemExit(main())
