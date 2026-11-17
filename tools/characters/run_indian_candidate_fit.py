"""Checkpointed isolated candidate fitting, stops on any Blender failure."""
import argparse,subprocess
from datetime import datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];HANDOFF=ROOT/'CODEX_HANDOFF.md'
BLENDER='/Applications/Blender.app/Contents/MacOS/Blender'
p=argparse.ArgumentParser();p.add_argument('identity',choices=['female_02','female_03','female_04']);args=p.parse_args()
slug=args.identity
upper='Street coherent cotton blouse and pallu';foundation='Opaque fitted bra and thong foundation';tail='Street sari back tail'
steps=[('tail surface','fit_indian_candidate_tail.py',[]),('rebuild foundation','rebuild_indian_candidate_foundation.py',[]),('refine foundation cut','refine_indian_candidate_foundation.py',[]),('fit foundation','fit_indian_body_candidate.py',['--garment',foundation]),('audit foundation','audit_indian_body_candidate.py',['--layer','foundation']),('fit blouse rest','fit_indian_candidate_layers.py',['--outer',upper,'--inner',foundation]),('fit blouse motion','fit_indian_candidate_motion_layers.py',['--outer',upper,'--inner',foundation]),('fit tail rest','fit_indian_candidate_layers.py',['--outer',tail,'--inner',upper]),('fit tail motion','fit_indian_candidate_motion_layers.py',['--outer',tail,'--inner',upper]),('audit layers','audit_indian_candidate_layers.py',[]),('audit upper','audit_indian_body_candidate.py',['--layer','upper']),('export candidate','export_indian_body_candidate.py',[])]
def record(message):
 s=HANDOFF.read_text();anchor='## Independent NPC activities and adult female secondary motion — /root\n';i=s.index(anchor)+len(anchor)
 HANDOFF.write_text(s[:i]+'\n- '+datetime.now().astimezone().isoformat(timespec='seconds')+': '+message+'\n'+s[i:])
for number,(label,script,extra) in enumerate(steps):
 cmd=[BLENDER,'--background','--python-exit-code','1','--python',str(ROOT/'tools/characters'/script),'--','--identity',slug,*extra]
 record(f'{slug}: starting {label} via {script}; next {steps[number+1][0] if number+1<len(steps) else "native review"}. Candidate remains unapproved.')
 print('CANDIDATE_FIT_STEP',slug,label,flush=True)
 result=subprocess.run(cmd,cwd=ROOT)
 if result.returncode:
  record(f'{slug}: {label} FAILED exit {result.returncode}; stop and inspect {script}, no automatic promotion. Exact next: diagnose this step and resume remaining sequence.')
  raise SystemExit(result.returncode)
 record(f'{slug}: {label} completed; next {steps[number+1][0] if number+1<len(steps) else "native review"}. Candidate remains unapproved.')
print('CANDIDATE_FIT_COMPLETE',slug,flush=True)
