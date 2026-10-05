"""Run in Blender to validate retained sources and remove reviewed obsolete files.

Blender --background --python tools/assets/audit_source_retention.py -- --apply
"""
from pathlib import Path
import hashlib
import json
import sys
import subprocess
import bpy

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "docs/assets/source_retention_2026-10-02.json"
FAILED = {
    "WorkingAssets/Arjun/reference_fit/arjun_continuous_drape_candidate.blend": "Failed lumpy drape/buried straps; replaced by projected-drape study",
    "WorkingAssets/Arjun/reference_fit/arjun_drape_boot_candidate.blend": "Failed wrap/boot detail; replaced by projected-drape study",
    "WorkingAssets/Arjun/reference_fit/arjun_hair_clump_candidate.blend": "Superseded hair study; later sculpted/material/eye/boot chain retained",
}
paths = sorted(p for folder in ("WorkingAssets", "environment") for p in (ROOT / folder).rglob("*") if p.is_file() and p.suffix in (".blend", ".blend1", ".blend2"))
dirty = set(subprocess.check_output(["git", "diff", "--name-only", "HEAD"], cwd=ROOT, text=True).splitlines())
retained = []
validated = {}
for path in paths:
    if path.suffix != ".blend" or str(path.relative_to(ROOT)) in FAILED:
        continue
    with bpy.data.libraries.load(str(path), link=False) as (source, _target):
        counts = {key: len(getattr(source, key)) for key in ("objects", "meshes", "armatures", "actions")}
    if counts["objects"] == 0:
        raise RuntimeError(f"Empty retained source: {path}")
    entry = {"path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "library_counts": counts, "reason": "Editable source or reproducible candidate dependency retained; no new visual approval"}
    validated[path] = entry
    retained.append(entry)

removed = []
for path in paths:
    relative = str(path.relative_to(ROOT))
    if relative in dirty:
        continue
    if relative in FAILED:
        reason = FAILED[relative]
        replacement = ROOT / "WorkingAssets/Arjun/reference_fit/arjun_projected_drape_candidate.blend"
    elif path.suffix in (".blend1", ".blend2"):
        replacement = Path(str(path)[:-1])
        if str(replacement.relative_to(ROOT)) in dirty:
            retained.append({"path": relative, "reason": "Backup belongs to concurrent modified source; kept"})
            continue
        if str(replacement.relative_to(ROOT)) in FAILED:
            replacement = ROOT / "WorkingAssets/Arjun/reference_fit/arjun_projected_drape_candidate.blend"
        if not replacement.exists() and relative == "WorkingAssets/arjun_body_v1.blend1":
            replacement = ROOT / "WorkingAssets/Arjun/arjun_body_v1.blend"
        if replacement not in validated or path.stat().st_mtime > replacement.stat().st_mtime:
            retained.append({"path": relative, "reason": "Backup newer than source or replacement not validated; kept"})
            continue
        reason = "Unreferenced automatic backup; current editable source validates in Blender"
    else:
        continue
    if replacement not in validated:
        raise RuntimeError(f"Replacement not validated: {replacement}")
    removed.append({"path": relative, "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "reason": reason, "retained_replacement": str(replacement.relative_to(ROOT))})

report = {"date": "2026-10-05 IST", "status": "PLANNED", "retained": retained, "removed": removed, "reclaimed_bytes": sum(p["bytes"] for p in removed), "validation": "Blender library directory read; not rendered appearance approval"}
REPORT.parent.mkdir(parents=True, exist_ok=True)
REPORT.write_text(json.dumps(report, indent=2)+"\n")
if "--apply" in sys.argv:
    for entry in removed:
        path = ROOT / entry["path"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
            raise RuntimeError(f"Source changed during audit: {path}")
        path.unlink()
    report["status"] = "APPLIED"
    REPORT.write_text(json.dumps(report, indent=2)+"\n")
print("SOURCE RETENTION", report["status"], "removed", len(removed), "retained", len(retained), "reclaimed_bytes", report["reclaimed_bytes"])
