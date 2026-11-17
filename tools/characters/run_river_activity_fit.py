"""Run checkpointed Blender fitting; disposable diagnostics and owned child cleanup."""
import subprocess,tempfile,argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--lower',action='store_true');args=parser.parse_args()
    script='fit_river_lower_correctives.py' if args.lower else 'fit_river_activity_clothes.py'
    with tempfile.TemporaryDirectory(prefix='tlm-river-activity-fit-') as folder:
        log=Path(folder)/'fit.log'
        with log.open('w') as output:
            process=subprocess.Popen(['/Applications/Blender.app/Contents/MacOS/Blender','--background','--python-exit-code','1','--python',str(ROOT/'tools/characters'/script)],cwd=ROOT,stdout=output,stderr=subprocess.STDOUT)
            try:code=process.wait(timeout=1800)
            finally:
                if process.poll() is None:process.terminate();process.wait(timeout=20)
        lines=log.read_text().splitlines()
        milestones=[line for line in lines if line.startswith(('RIVER_ACTIVITY_FIT','RIVER_LOWER')) or 'RuntimeError:' in line]
        for line in milestones[:1]+milestones[-5:]:print(line,flush=True)
        if code:print('\n'.join(lines[-12:]),flush=True)
        return code
if __name__=='__main__':raise SystemExit(main())
