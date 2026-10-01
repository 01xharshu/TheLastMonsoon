# Riding clothing folds and saddle refinement
Updated: 2026-10-01 11:26 IST. Chat 01a0e88d-3689-7963-8dd7-09f101cc449c.
Status: IN_PROGRESS. Fold/saddle and seated seam passes integrated and verified; small slit-edge tips, final cloth contact and full-world review remain open.

## Implemented
- Reauthored the two trouser-leg surfaces in a separate recoverable Blender source. Dense 13/21 repeating corrugations became broader 3/5 gathers with restrained diagonal breaks, preserving waist and boot openings, thickness and original skin. Live body and source rig were preserved.
- Separate garment GLB transfers only garment surfaces into the existing live skin; existing pelvis/thigh/calf fitting is retained. Plain off-white cotton uses the existing cloth shader. Setup occurs before shader assignment so the original atlas is not applied to incompatible UVs.
- Replaced flat saddle pad and oval seat parts with a closed curved pad, narrower padded seat, connected raised bows, cloth binding and fitted metal stirrup loops. Tack follows the animated horse frame.

## Recoverable files
`WorkingAssets/Arjun/riding_cloth/arjun_riding_cloth.blend`, `manifest.json`; builder `tools/characters/refine_arjun_riding_cloth.py`; separate output `characters/arjun/arjun_riding_cloth.glb`. Original `WorkingAssets/Arjun/candidate/arjun_animated_candidate.blend` and `characters/arjun/arjun.glb` are retained. Runtime fitting `player/arjun_trouser_fit.gd`, shader setup order `player/arjun_clothing.gd`; tack module `horses/fitted_saddle.gd`, integration `horses/stable_horse.gd`.

## Historical basis
[Met Indian 19th-century saddle](https://www.metmuseum.org/art/collection/search/31905) documents wood/leather construction, but its date is too broad to authenticate an exact 1850s local pattern. [Rijksmuseum Hugh Owen 1851 photograph](https://id.rijksmuseum.nl/200474710) documents an embroidered Indian exhibition saddle. Those sources guide construction category; the current plain tack is an original simplified game model, not a reconstruction of the luxury exhibit.

## Verification and evidence
- Blender export and Godot import PASS: `/tmp/tlm_riding_cloth_final_build_oct01.log`, `/tmp/tlm_riding_cloth_final_import_oct01.log`.
- Headless mounted geometry/contact/timing PASS; `/tmp/tlm_cloth_saddle_headless_oct01.log`. This preceded the final fold-amplitude adjustment.
- Current native Metal mounted sequence PASS, 102 samples, max sampling gap five physics ticks. Knees remain bent, seated/gallop/jump forward response retained, seat/sole/rein residuals below 0.000004 m. `riding_cloth_saddle_metal.json`, `/tmp/tlm_cloth_saddle_current_metal_oct01.log`.
- Fresh close idle, walk, gallop, jump and recovery pixels inspected: `captures/riding_cloth_saddle_idle.png`, `_walk.png`, `_gallop.png`, `_jump.png`, `_recovery.png`. Before views `_before_idle.png` and `_before_jump.png` are preserved for comparison.
- Standing/run garment guard captures: `docs/characters/arjun/clothing_2026-09-30/riding_refined_idle.png`, `riding_refined_run.png`, logs `/tmp/tlm_cloth_refined_idle_oct01.log`, `/tmp/tlm_cloth_refined_run_oct01.log`; these preceded final gather-depth adjustment, with identical skin/fitting.
- Current close sequence MP4/GIF: `captures/riding_cloth_saddle.mp4`, `.gif`, encoded from actual physics timestamps, original aspect preserved. Capture command: `/Applications/Godot.app/Contents/MacOS/Godot --path . --windowed --resolution 1280x720 --rendering-driver metal --fixed-fps 60 --script res://tools/horses/validate_rider_seated_motion.gd -- --close`. Frames and concat input `/tmp/tlm_rider_motion/frame_%04d.png`, `cloth_sequence.txt`.

## Limits and next action
This is a cloth/tack refinement, not final character approval. Upper trouser/kurta junction and close compression/contact still merit tailoring review; numeric sockets do not certify skin/cloth clearance. Exact regional saddle pattern and full-world owner riding feel remain open. Preserve concurrent rein-grip/cart, character and world work. Next: round the remaining short slit-edge tips and inspect mounted entry/exit plus full-world movement; current preview is the stitched seam revision. Uniform hoof sound remains the existing implementation.

Final delivery: current walk/gallop/jump/recovery pixels inspected; revised close preview encoded successfully, 1280x720, 6.833333 seconds, GIF 2.5 MB. Codex MP4 open queued. Documentation gate PASS (60 lines/5896 characters) and source whitespace check PASS.

## Seated seam continuation — IN_PROGRESS
Updated: 2026-10-01 11:20 IST, root/current chat. Scope: trouser upper rim and kurta overlap, preserving body, saddle and uniform hoof audio. Baseline image shows thin pale points above the seated thigh. Next: inspect upper-rim weighting, tailor garment overlap, recapture close mounted motion and standing/run. No new edits or verification yet.

Seam edit: trouser and split-hem weights now share the 0.96–1.04 m hip blend (smoothstep). Previous trouser 0.82–0.98 m blend anchored the thigh opening early, exposing it above the seated hem. Only garment bind arrays changed; body/source geometry and tack preserved. Files: `player/arjun_trouser_fit.gd`, `player/arjun_clothing.gd`. Next native close movement capture; visual outcome unverified.

First seam capture: mounted contact/timing PASS (`/tmp/tlm_seam_metal_oct01.log`), but pale slit edges remain in native idle pixels. Source inspection found high-frequency corrugations in the split hem itself. Recoverable builder now also exports a restrained broad-fold hem with original cut, thickness and side splits; runtime transfers that surface before hem weights/shader assignment. Next rebuild/import and fresh native review.

Recoverable source rebuild/import completed successfully: `/tmp/tlm_seam_source_oct01.log`, `/tmp/tlm_seam_import_oct01.log`; original body and source candidate preserved. Native final sequence running (`/tmp/tlm_seam_final_metal_oct01.log`); next inspect resulting slit/overlap in idle/gallop/jump.

Second visual review: broad hem folds reduce seated points, but a narrow slit still reveals a pale spike during jumping. Source seam now closes the upper three slit rows, retaining the lower opening. Next rebuild/import and repeat close check; do not claim slit fix until pixels reviewed.

Stitched source native Metal motion PASS: `/tmp/tlm_seam_stitched_metal_oct01.log`, 102 samples; `riding_cloth_saddle_metal.json` copied. Fresh idle/gallop/jump/recovery pixels inspected: long pale slit spikes reduced to small edge tips, seated overlap broader/smoother. Small edge silhouette still needs art review; no final cloth clearance approval. Current captures and source hash manifest refreshed. Standing/run guards and preview encoding next.

## Current continuation result — 2026-10-01 11:26 IST
- Seam source and runtime integration completed. Trouser/hem transition matched; original high-frequency hem gathers relaxed; upper three slit rows stitched with lower opening retained. Original body/base and source candidate retained, saddle/hoof implementation preserved.
- Fresh native 102-sample seated/walk/gallop/jump/recovery checks PASS, with continuous timing and original contact/lean responses (`/tmp/tlm_seam_stitched_metal_oct01.log`). Native pixel inspection shows reduced long spikes; small short slit tips remain visible, especially at run/jump extremes. These remain an art defect, not final outfit approval.
- Fresh standing and run guard captures inspected: `docs/characters/arjun/clothing_2026-09-30/riding_seam_idle.png`, `riding_seam_run.png`; logs `/tmp/tlm_seam_idle_oct01.log`, `/tmp/tlm_seam_run_oct01.log`. No major silhouette disruption in those two sampled poses; these are not full 1.0x entry/exit/deformation approval.
- Current MP4/GIF and stage captures refreshed, physics-timed 6.833333 seconds at 1280x720. Source hashes refreshed in `captures/riding_cloth_saddle_manifest.json`; source rebuild/import logs `/tmp/tlm_seam_source_oct01.log`, `/tmp/tlm_seam_import_oct01.log`.
- Exact next action: round/finish the short split edges in the recoverable hem source, then capture mounted entry/exit and normal-speed full-world riding. Preserve concurrent rein/cart work.
