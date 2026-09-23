"""Original synthesized prototype effects; no third-party recordings."""
import math, random, struct, wave
from pathlib import Path
out=Path(__file__).resolve().parents[2]/'audio/weapons'
out.mkdir(parents=True,exist_ok=True)
random.seed(1853)
for name,duration in [('enfield_shot',1.6),('enfield_reload',0.7),('enfield_empty',0.16)]:
    samples=[]; low=0.0
    for i in range(int(44100*duration)):
        t=i/44100; noise=random.uniform(-1,1);low=low*.91+noise*.09
        if name=='enfield_shot':
            value=(noise*.65*math.exp(-t*38)+low*2.0*math.exp(-t*4)+math.sin(2*math.pi*65*t)*.26*math.exp(-t*9))
        else:
            value=sum(noise*.35*math.exp(-(t-start)*90) for start in ([0,.18,.48] if name=='enfield_reload' else [0]) if t>=start)
        samples.append(struct.pack('<h',int(max(-.95,min(.95,value))*32767)))
    with wave.open(str(out/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(44100);f.writeframes(b''.join(samples))
