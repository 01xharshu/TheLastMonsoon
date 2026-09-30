# Horse body and uniform hoof sound — 2026-09-30
Updated: 2026-09-30 17:10 IST. Chat 01a0e88d-3689-7963-8dd7-09f101cc449c.
Status: integrated refinement; final anatomy, tack, continuous motion and historical breed approval open.

## Changes
- Rounded barrel, shoulder and haunch; tapered upper neck and restored dorsal volume. Welded duplicate source borders before subdivision, preserving 50 bones and existing animation actions. Bay coat shading simplified.
- Recoverable original remains `WorkingAssets/Horse/candidates/quaternius_horse/rigged_horse_candidate.blend`; source is the existing CC0 Quaternius horse. This is a generic horse refinement, not a documented Indian breed reconstruction.
- Builder `tools/horses/refine_rigged_body.py`; refined blend and manifest under `WorkingAssets/Horse/candidates/body_refinement/`; runtime GLB `assets/animals/horse/horse_body_refinement.glb`, SHA256 47978d2e3a1b2e12cf30ec841149fefd4e67b330cc407e398a4b3d19ac5182c7, 6548 vertices.
- Actual ridden horse and both cart/carriage visual preloads use the refinement.
- Owner correction: existing recorded hoofbeat A/B pair now used on every surface for ridden horse, cart and carriage, identical -8 dB and deterministic pitch variation. Landing, tack and voice unchanged.

## Evidence
- Blender build/export and headless Godot import completed. Logs `/tmp/tlm_horse_body_build_20260930.log`, `/tmp/tlm_horse_weld_import_20260930.log`.
- Native Metal side/front/quarter idle and Walk/Gallop/Gallop_Jump samples inspected: surface holes from first rejected export resolved. `tools/horses/capture_body_refinement.gd`; `docs/world/captures/horse_body_after_*.png`; `/tmp/tlm_horse_weld_motion_20260930.log`.
- Actual mounted fixture headless and Metal PASS: cart sprint, horse boarding/gallop/jump/landing, palms rounded 0.000 m and soles maximum 0.004 m. `tools/horses/validate_mounted_realism.gd`; logs `/tmp/tlm_horse_refined_mount_20260930.log`, `/tmp/tlm_horse_refined_mount_metal_20260930.log`. Metal rider captures inspected.
- Uniform hoof validator PASS, 90 actual script stream/mix/pitch events over earth/road/timber and all three horse routes: `tools/horses/validate_uniform_hoof.gd`, `docs/world/uniform_hoof_validation.json`, `/tmp/tlm_uniform_hoof_20260930.log`.
- Headless shutdown reports leaked ObjectDB/resources; Metal mounted run exits cleanly. Numeric palm/sole contact does not establish cloth, saddle or continuous gait approval.

## Remaining work
Saddle cloth still resembles a rigid flat plate; saddle/straps and neck/leg anatomy remain simplified. Frozen animation fixture reveals jump saddle separation because runtime physics/tack following is disabled there. Live rider samples still have clothing defects. Review continuous normal-speed gait, saddle contact and horse proportions against dated regional references before final realism approval. Sound source equality is verified; auditory mix/owner feel remains open.
