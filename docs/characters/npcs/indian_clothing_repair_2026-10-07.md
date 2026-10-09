# Indian NPC clothing repair

Updated: 2026-10-08 10:48 IST / root. Status: IN_PROGRESS. User reports unrealistic clothes and body leakage during actions. The first four village outfits now pass focused source/native body-contact checks; final fabric realism and all gameplay actions remain open. Preserve concurrent purpose NPC, river woman, Arjun and world work.

## Implemented

- Farmer, village woman, fruit seller and weaver assistant garments fitted over unchanged complete MPFB bodies. Separate opaque adult foundation garments retained; runtime bodies each have 14,517 vertices. No covered body surfaces removed.
- Editable fitted sources and provenance manifests: `WorkingAssets/NPCs/<role>/<role>_clothing_fitted.blend`, `clothing_fit_manifest.json`. Original motion/MPFB sources retained. All four current source/runtime hashes match their manifests.
- Runtime exports: `characters/npcs/motion/<role>/<role>_rigged_candidate.glb`. Correctives travel with the matching idle/walk animations at60Hz, preserving2s idle/1.2s walk. All bone influences exported (body has up to7); imports use60Hz with mesh compression disabled.
- Upper skin weights corrected, male shirt tails trimmed inside overlapping kurta, kurta fitted outside dhoti, female arm clearance corrected, sari/pallu fitted outside blouse. Complete body unchanged.
- Both quad diagonals and neighbouring morph keys constrained. Godot chose triangles that earlier polygon/one-diagonal source checks missed. Mixed idle/walk body poses also constrained; three transition repairs per male, then canonical recheck (farmer0/weaver3 repairs).
- `characters/npcs/indian_peasant_pair.tscn` now uses independent fitted animated actors, preserving child names/transforms and Bhairavpur world placement(-310,7.2,230).

## Current verification

- Fresh Godot import PASS.
- `Godot --headless --path . --script res://tools/characters/validate_village_clothing.gd`: PASS complete bodies, foundations, garment tracks, clip lengths/weights, independent trees and placed pair. Two exit ObjectDB warnings remain.
- Blender `audit_village_clothing.py -- all --clip idle --substeps 2` and same with `--clip walk`: PASS all four,120Hz vertex and both-diagonal triangle-centre checks, zero penetrations beyond2mm.
- `python3 tools/characters/run_village_runtime_audit.py`: PASS all four actual imported skin/morph surfaces, including .05s samples through .2s idle/walk/return blends. 1,193,904 checks, zero penetrations beyond2mm. Two exit ObjectDB warnings remain.
- Python compilation and `git diff --check`: PASS.
- Fresh Metal woman idle pixels inspected: coverage improved, but sari/pallu still rigid/faceted and sleeve edges need art work. Capture repeatedly stalled and timed out after partial images; normal-speed Metal motion is unverified. All disposable captures, geometry, reports and logs removed. No retained test output provides acceptance.

## Reusable tools and exact next action

- `repair_village_clothing.py -- ROLE` rebuilds original motion source and fit; `run_village_fit.py ROLE...` refines existing fitted sources; `--export-only` preserves fits while rebuilding GLBs; `--body-contact-only` skips further layer fitting.
- `run_village_transition_fit.py` owns temporary native samples, fits two male mixed poses and rechecks canonical poses, then exports. Reimport before native validation after any export.
- `capture_village_clothing.gd` requires `TLM_CLOTHING_TEST_OUTPUT` in an OS temporary directory and a caller timeout/finally cleanup. It now forces actor processing through pause and windowed sizing after startup; this diagnostic change has not yet been rerun.
- Next: establish reliable1.0x target-renderer review with this updated capture, then reshape the rigid pallu/skirts and smooth sleeve construction; re-run source/native contact after geometry changes. Do not call cloth realism approved from current contact PASS.
- Then trace `characters/npcs/households/household_npc_actor.gd` and `british/british_npc_actor.gd` generated idle/walk/turn/work/combat plus cart seated consumers. They generate separate animations and do not consume these exported clip correctives. Author/fix relevant transitions/contact for each consumer; passing the four source clips does not certify those actions.
- Purpose/clerk/river families have separate active owners and failures in their focused docs; preserve their assets and ownership. Full-world motion/contact/performance and final owner approval remain open.
