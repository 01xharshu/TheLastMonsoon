"""Original deterministic synthesized opening foley; no sampled recordings."""
import math, random, struct, wave, json
from pathlib import Path
OUT = Path(__file__).resolve().parents[2]/'assets/audio/opening'
RATE = 22050
def write(name, duration, sound, loop=False):
    rng = random.Random(71007+len(name))
    values = []
    low = 0.0
    for i in range(int(RATE*duration)):
        t = i/RATE
        white = rng.uniform(-1,1)
        low = .88*low+.12*white
        v = sound(t, white, low)
        fade = min(1,t/.015,(duration-t)/.025)
        values.append(struct.pack('<h',round(32767*max(-.95,min(.95,v*fade)))))
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setparams((1,2,RATE,0,'NONE','not compressed'))
        f.writeframes(b''.join(values))
write('match_strike',.40,lambda t,n,l:(n-l)*.22*math.exp(-t*8)*(0.3+0.7*math.sin(t*290)**2))
write('wick_catch',.24,lambda t,n,l:.15*l*math.exp(-t*20))
write('match_exhale',.46,lambda t,n,l:.28*l*math.sin(math.pi*t/.46)**1.3)
write('room_step',.26,lambda t,n,l:.19*l*math.exp(-t*25)+.1*math.sin(2*math.pi*85*t)*math.exp(-t*35))
write('cot_creak',.8,lambda t,n,l:.10*l*math.sin(math.pi*t/.8)+.025*math.sin(2*math.pi*(210+40*math.sin(t*17))*t)*math.sin(math.pi*t/.8))
write('cloth_rustle',.55,lambda t,n,l:.11*(n-l)*math.sin(math.pi*t/.55)**2*(.5+.5*math.sin(t*71)**2))
print('OPENING FOLEY: 6 original synthesized foley cues; directed voice remains separate')
with wave.open(str(OUT/'arjun_murmur_draft.wav'),'rb') as f:
    assert f.getsampwidth() == 2
    rate, channels = f.getframerate(), f.getnchannels()
    raw = f.readframes(f.getnframes())
    samples = struct.unpack('<'+'h'*(len(raw)//2),raw)
    window = max(1,round(rate*.02))*channels
    rms = [math.sqrt(sum((x/32768)**2 for x in samples[i:i+window])/max(1,len(samples[i:i+window]))) for i in range(0,len(samples),window)]
    peak = sorted(rms)[int(.95*(len(rms)-1))]
    envelope = [min(1,max(0,(v/peak-.07)/.93)) for v in rms]
    (OUT/'arjun_murmur_envelope.json').write_text(json.dumps({'step_seconds':.02,'amplitudes':envelope})+'\n')
