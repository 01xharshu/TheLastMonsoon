"""Deterministic original synthesized effects; no third-party samples."""
import math, random, struct, wave, argparse
from pathlib import Path
root=Path(__file__).resolve().parents[2]/'audio/world'
root.mkdir(parents=True,exist_ok=True)
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--only", help="Rebuild one named effect")
args=parser.parse_args()
for name,duration in [('step_dirt',.18),('step_stone',.14),('step_wood',.19),('splash',.32),('impact',.22),('cloth',.24),('paper',.35),('door',.55),('wind',8.0)]:
 if args.only and name != args.only: continue
 rng=random.Random(name); rate=22050; samples=[]; low=0.0
 for i in range(int(duration*rate)):
  t=i/rate; n=rng.uniform(-1,1);low=.94*low+.06*n
  envelope=1.0 if name=='wind' else (1-math.exp(-t*200))*math.exp(-t/(duration*.23))
  if name=='wind': value=low*1.5
  elif name in ('cloth','paper','splash'):value=(n*.35+low)*(.65 if name=='splash' else .35)
  else:value=n*.18+math.sin(t*math.tau*({'step_wood':135,'step_stone':260,'door':85,'impact':65}.get(name,95)))*.55
  samples.append(struct.pack('<h',int(max(-1,min(1,value*envelope*.65))*32767)))
 with wave.open(str(root/(name+'.wav')),'wb') as f:f.setparams((1,2,rate,0,'NONE','not compressed'));f.writeframes(b''.join(samples))
