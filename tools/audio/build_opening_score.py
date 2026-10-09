"""Build the original temporary prologue score; replace the WAV for final music."""
from pathlib import Path
import math
import struct
import wave

RATE = 22050
DURATION = 24
OUT = Path(__file__).resolve().parents[2] / "assets/audio/opening/prologue_tension_draft.wav"

def sample(t):
    # Whole-cycle oscillators and slow envelopes join seamlessly over 24 seconds.
    breath = .65 + .35 * math.sin(math.tau * t / 12) ** 2
    drone = .24 * math.sin(math.tau * 55 * t)
    drone += .10 * math.sin(math.tau * 82.5 * t)
    drone += .055 * math.sin(math.tau * (116 + 13 / 24) * t)
    bow = .04 * math.sin(math.tau * (165 + 1 / 24) * t)
    bow *= .4 + .6 * math.sin(math.tau * t / 24) ** 2
    pulse = .025 * math.sin(math.tau * 110 * t) * max(0, math.sin(math.tau * t / 3)) ** 4
    return (drone + bow + pulse) * breath

if __name__ == "__main__":
    with wave.open(str(OUT), "wb") as output:
        output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        output.writeframes(b"".join(struct.pack("<h", round(32767 * sample(i / RATE)))
                                   for i in range(RATE * DURATION)))
    print("Original temporary prologue score rebuilt (24 second seamless loop).")
