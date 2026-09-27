"""Fetch the exact Poly Haven 1K glTF packages used by period world props."""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/props/polyhaven"
ASSETS = ("wooden_crate_02", "wooden_bucket_02")
records = []

for asset in ASSETS:
    api = subprocess.check_output(["curl", "-fsSL", f"https://api.polyhaven.com/files/{asset}"])
    package = json.loads(api)["gltf"]["1k"]["gltf"]
    sources = {f"{asset}_1k.gltf": package, **package["include"]}
    for name, info in sources.items():
        target = DEST / asset / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.exists():
            subprocess.run(["curl", "-fL", "--retry", "3", "-o", str(target), info["url"]], check=True)
        data = target.read_bytes()
        if hashlib.md5(data).hexdigest() != info["md5"]:
            raise ValueError(f"Poly Haven MD5 mismatch: {target}")
        records.append({
            "path": str(target.relative_to(ROOT)),
            "source": info["url"],
            "sha256": hashlib.sha256(data).hexdigest(),
            "license": "CC0-1.0",
            "asset_page": f"https://polyhaven.com/a/{asset}",
        })

(ROOT / "docs/world/period_prop_manifest.json").write_text(json.dumps(records, indent=2) + "\n")
print(f"Verified {len(records)} Poly Haven source files")
