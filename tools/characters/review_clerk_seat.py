"""Open the isolated clerk seat study at 1.0x; always discard test output."""
import os, subprocess, tempfile, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
    subprocess.run([sys.executable,str(ROOT/'tools/characters/audit_clerk_seat_body.py')],check=True)
    with tempfile.TemporaryDirectory(prefix='tlm-clerk-seat-') as output:
        env=os.environ.copy();env['TLM_REVIEW_DIR']=output;env['TLM_REVIEW_REALTIME']='1'
        try:
            subprocess.run(['/Applications/Godot.app/Contents/MacOS/Godot','--path',str(ROOT),
                            '--rendering-driver','metal','--script',
                            'res://tools/characters/capture_clerk_seat_study.gd'],env=env,check=True)
        except KeyboardInterrupt:
            print('Review interrupted; temporary output discarded.')
            raise
if __name__=='__main__':main()
