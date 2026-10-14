"""Resumable canonical upper-cloth rebind with disposable logs and owned cleanup."""
import os,signal,tempfile
from pathlib import Path
import rebuild_river_woman as runner
def main():
    def interrupted(_signal,_frame):raise KeyboardInterrupt
    signal.signal(signal.SIGTERM,interrupted)
    runner.PREFIXES+=('RIVER_UPPER_REBIND',)
    with tempfile.TemporaryDirectory(prefix='tlm_river_upper_rebind_') as folder:
        commands=[
            [runner.BLENDER,'--background','--python-exit-code','1','--python',str(runner.ROOT/'tools/characters/rebind_river_upper.py')],
            [runner.GODOT,'--headless','--editor','--path',str(runner.ROOT),'--log-file',str(Path(folder)/'import.log'),'--import'],
        ]
        for index,command in enumerate(commands):
            if not runner.run_step(command,dict(os.environ),Path(folder)/('step_'+str(index)+'.log')):return 1
    return 0
if __name__=='__main__':raise SystemExit(main())
