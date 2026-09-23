"""Generate original, deterministic short horse foley at 22050 Hz, mono PCM.
No sampled third-party audio is used. The separate horse_neigh.ogg has its own provenance.
"""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[2] / 'audio/horses'
RATE = 22050
ROOT.mkdir(parents=True, exist_ok=True)

def save(name, samples):
    peak = max(max(abs(v) for v in samples), 1e-6)
    gain = min(.75 / peak, 2.5)
    with wave.open(str(ROOT / name), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, v*gain))*32767)) for v in samples))

def hoof(name, seed, low_hz, length, heavy=False):
    rng = random.Random(seed)
    low = 0.0
    high = 0.0
    samples = []
    for i in range(int(RATE*length)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low += (noise-low) * .075
        high += (noise-high) * .36
        thud = math.sin(2*math.pi*(low_hz*t + 22*t*t)) * math.exp(-t*25)
        grit = (high-low) * math.exp(-t*32)
        dirt = low * math.exp(-t*12)
        onset = min(1, t*2800)
        samples.append(onset*(.56*thud + .38*grit + .22*dirt)*(1.45 if heavy else 1))
    save(name, samples)

hoof('hoof_dirt_01.wav', 1857, 93, .20)
hoof('hoof_dirt_02.wav', 1858, 81, .23)
hoof('hoof_landing.wav', 1859, 68, .43, True)

def firm_hoof(name, seed, wood=False):
    rng = random.Random(seed)
    low = 0.0
    samples = []
    length = .25 if wood else .19
    for i in range(int(RATE*length)):
        t = i/RATE
        n = rng.uniform(-1,1)
        low += (n-low)*(.045 if wood else .12)
        click = (n-low)*math.exp(-t*(65 if wood else 85))
        resonance = math.sin(2*math.pi*(185 if wood else 125)*t)*math.exp(-t*(17 if wood else 29))
        samples.append(.32*click + (.38 if wood else .23)*resonance + .10*low*math.exp(-t*20))
    save(name,samples)

firm_hoof('hoof_packed_road.wav',1862)
firm_hoof('hoof_timber.wav',1863,True)

rng = random.Random(1860)
low = 0.0
samples = []
for i in range(int(RATE*.42)):
    t = i/RATE
    n = rng.uniform(-1,1)
    low += (n-low)*.025
    f = 140 + 110*math.sin(math.pi*t/.42)
    creak = math.sin(2*math.pi*f*t + .8*math.sin(2*math.pi*19*t))
    envelope = math.sin(math.pi*min(1,t/.42))**1.8
    samples.append(envelope*(.22*creak+.13*low))
save('leather_tack.wav',samples)

rng = random.Random(1861)
low = 0.0
samples = []
for i in range(int(RATE*.72)):
    t = i/RATE
    n = rng.uniform(-1,1)
    low += (n-low)*.12
    pulse = math.exp(-((t-.19)/.12)**2) + .7*math.exp(-((t-.48)/.11)**2)
    breath = low*.55 + .08*math.sin(2*math.pi*65*t)
    samples.append(breath*pulse)
save('horse_snort.wav',samples)
print('HORSE SFX: generated 7 original WAV files')
