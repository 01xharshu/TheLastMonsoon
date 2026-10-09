#!/usr/bin/env python3
"""Render a pistol sequence in temporary storage, then remove all review output."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("--side", action="store_true")
    parser.add_argument("--charges", type=int, choices=range(1, 6), default=1)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix="tlm-pistol-") as output:
        env = dict(os.environ, TLM_PISTOL_REVIEW_OUTPUT=output,
                   TLM_PISTOL_REVIEW_CHARGES=str(args.charges),
                   TLM_PISTOL_REVIEW_SIDE="1" if args.side else "0")
        subprocess.run([args.godot, "--path", str(project), "--script",
                        "res://tools/weapons/capture_pistol_motion_review.gd"],
                       env=env, timeout=150, check=True)
        print(f"Review images: {output}", flush=True)
        input("Press Enter after inspecting the images to delete them: ")


if __name__ == "__main__":
    main()
