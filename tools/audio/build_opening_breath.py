"""Original synthetic breath candidate; reproducible, no sampled recording."""
import math, random, struct, wave
from pathlib import Path
rng = random.Random(3105)
rate, duration = 22050, 1.25
samples = []
filtered = 0.0
for i in range(int(rate * duration)):
    t = i / rate
    filtered = .72 * filtered + .28 * rng.uniform(-1, 1)
    envelope = math.sin(math.pi * t / duration) ** 1.4
    samples.append(struct.pack('<h', int(32767 * .18 * envelope * filtered)))
p = Path(__file__).resolve().parents[2] / 'assets/audio/opening/arjun_sigh_draft.wav'
with wave.open(str(p), 'wb') as out:
    out.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    out.writeframes(b''.join(samples))
