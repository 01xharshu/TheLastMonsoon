"""Original physical contact textures for quiet NPC work and equipment."""
import math,random,struct,wave
from pathlib import Path
root=Path(__file__).resolve().parents[2]/'audio/world'
for name,duration in [('quill',.5),('wood_knock',.16),('metal_clink',.4),('wheel_creak',.65),('chew',.3)]:
 rng=random.Random(name);low=0;data=[];rate=22050
 for i in range(int(rate*duration)):
  t=i/rate;n=rng.uniform(-1,1);low=.85*low+.15*n
  env=math.sin(math.pi*t/duration)**2
  if name=='quill':v=(n-low)*.09*(.5+.5*math.sin(t*54))
  elif name=='saw':v=(n-low)*.16*(.5+.5*math.sin(t*31))
  elif name=='chew':v=low*.32*(.4+.6*math.sin(t*27)**2)
  elif name=='wheel_creak':v=(math.sin(t*math.tau*(180+12*math.sin(t*19)))+n*.12)*.13
  elif name=='metal_clink':v=sum(math.sin(t*math.tau*f) for f in (1173,1934,2719))*.15*math.exp(-t*11)
  else:v=(math.sin(t*math.tau*170)*.5+n*.14)*math.exp(-t*29)
  data.append(struct.pack('<h',int(max(-1,min(1,v*env))*32767)))
 with wave.open(str(root/(name+'.wav')),'wb') as f:f.setparams((1,2,rate,0,'NONE','not compressed'));f.writeframes(b''.join(data))
print('5 original work textures built')
