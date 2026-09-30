# Bhairavpur architecture and craft detail

Status: **COMPLETE** for architecture/craft pass. Updated: 2026-09-30 16:05 IST.
Chat: `01a0e88d-3689-7963-8dd7-09f101cc449c`.

Objective: continue the expanded village with architectural variety, complete roof/gable construction, household interiors, recognizable craft workshops and differentiated market wares. Keep the existing 33 homes, footprint and routes; additional residents remain deferred per owner instruction.

Completed: read AGENTS/handoff and [expanded construction evidence](bhairavpur_village_construction.md), inspected current village module/builder and dirty worktree. The prior expansion remains present. Current roof pieces repeat one silhouette and leave gable openings; sleeping platforms lack visible supports. Concurrent player/ammunition/character changes must be preserved.

Files changed this run: handoff/this record, `world/suryagarh/settlements/bhairavpur_village.gd`; added `bhairavpur_house_detail.gd` and `village_surface.gdshader` beside it, plus `tools/world/capture_village_detail.gd` and `tools/world/validate_village_detail.gd`. Three roof families, real rear windows, framed entrances/gates, supported sleeping platforms, cooking/storage furnishings and carpenter/weaver/potter homes are implemented. Market stock now differs between produce, grain, cloth, pottery and timber. Headless helper parse and `git diff --check` PASS; Headless actual-player checks PASS: all 33 homes entered/exited, all three workstations stopped the player, and two lanes remained traversable. Report: `docs/world/village_detail_headless.json`; log: `/tmp/tlm_village_detail_headless_20260930.log`. Exit reported two leaked ObjectDB instances and one retained resource; scene checks passed. Metal runtime/render checks pending. Blockers: none.

Exact next action: run `Godot --headless --path . --fixed-fps 60 --script res://tools/world/validate_village_detail.gd` and `Godot --path . --windowed --resolution 1280x720 --rendering-driver metal --script res://tools/world/capture_village_detail.gd` using `/Applications/Godot.app/Contents/MacOS/Godot`. Inspect fresh views and fix defects, then repeat seven selected home entrance/exit checks and workstation contact under Metal with the validator's `-- --metal-samples` argument. Final art, every-house interior review and owner normal play remain separate gates.

Metal captures exposed old roof/rear-wall geometry retained by the shared builder pre-merge. Fixed by deferring only village building merges until after detail replacement, including duplicate automatically named roof pieces. Rerun headless traversal and Metal captures/contact next.

Second Metal review verified terrace replacement and rear window openings, but revealed reversed gable face winding. Reversed triangle winding before final capture and Metal controller checks.

Gable remained omitted after winding repair: non-indexed custom geometry mixed with indexed BoxMesh surfaces during batching. Indexed custom generated surfaces before merging; final renderer confirmation pending.

Final verification: headless all 33 entry/exit pairs, three workstation contacts and two lanes PASS after deferred merge. Metal seven representative entry/exit pairs, three stations and two lanes PASS (`village_detail_metal.json`, `/tmp/tlm_village_detail_metal_20260930.log`). Final 10-view Metal capture exited cleanly; inspected closed tile/thatch gables, terrace, rear windows, supported bed and three workshops. Indexed generated custom surfaces fixed batching omission. Headless exit retained four ObjectDB instances/two resources; no scene assertions failed. Full owner play and all-house final art review remain open.

Next scope (owner Sep 30): research 1850s Indian rural estates/houses/roads, integrate existing oil lamps and nighttime light spill, gathering fires, pond access and bridges. Additional residents still follow NPC clothing/gait fixes.
