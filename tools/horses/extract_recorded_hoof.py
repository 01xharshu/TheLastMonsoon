"""Cut two individual hard-surface impacts from the credited WWS recording.

Source and license are recorded in audio/horses/README.md. Requires ffmpeg.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "WorkingAssets/Horse/audio_sources/wws_shod_horse_pavement.ogg"
OUT = ROOT / "audio/horses"
for name, start in (("hoof_road_recorded_01.wav", 3.05), ("hoof_road_recorded_02.wav", 3.34)):
    subprocess.run([
        "ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-ss", str(start),
        "-i", str(SOURCE), "-t", "0.29", "-af",
        "highpass=f=90,lowpass=f=6000,afade=t=in:st=0:d=0.008,afade=t=out:st=0.23:d=0.06",
        "-ac", "1", "-ar", "22050", "-c:a", "pcm_s16le", str(OUT / name),
    ], check=True)
