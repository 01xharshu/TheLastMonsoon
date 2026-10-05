# Arjun multi-view fit — 2026-10-05

**NOT_EXACT / VISUAL_MATCH_FAILED.** The owner core and equipped boards in `WorkingAssets/Arjun/references/` remain the target. Current work reuses the existing MakeHuman/MPFB body and rig; no replacement human was constructed. The playable GLB has not been replaced.

## Current editable source and evidence

Latest combined source: `WorkingAssets/Arjun/reference_fit/arjun_complete_body_fitted_candidate.blend`. Required parents include `arjun_complete_body_candidate.blend` and `arjun_eye_contact_candidate.blend`; earlier sculpted/material/eye/boot inputs remain in the rebuild chain.

[Four-view comparison](reference_fit/current/reference_comparison.png), [front face](reference_fit/current/face.png), [three-quarter face](reference_fit/current/face_three_quarter.png), [boot front](reference_fit/current/boot_front.png), [boot side](reference_fit/current/boot_side.png), [boot quarter](reference_fit/current/boot_quarter.png), and [torso/sash](reference_fit/current/cloth.png). Full front/side/back/three-quarter renders and capture provenance are in `reference_fit/current/`.

## Changes checked in renders

Boots: rebuilt four continuous vamp panels and twelve continuous shaft-wrap panels; removed the original duplicate buckle set, seated the remaining frames, removed inherited sole corrugation, added subdued edge stitching and varied leather roughness. Front/side/quarter close-ups now show continuous panels and cleaner crossing edges. The wrapped silhouette, toe/heel construction and detailed wear still differ from the reference; this is not final art or motion approval.

Face: duplicated iris texture artifacts removed; fine tapered moustache strands replace the fused patch. Latest reversible eyelid contact key moves vertices by at most 1.203 mm; front/three-quarter renders show less exposed eye white without collapsed lids. Brows darkened and thickened slightly. Identity, facial proportions, skin detail, moustache shape and profile remain visibly different. Vertex count and bounded displacement are diagnostics, not likeness approval.

Clothes: floating gold sash wires removed and pattern moved into the cloth shader. Cloth still looks too smooth, pattern too regular, and trousers lack the owner's asymmetrical overlapping drape. Hair still reads as molded strips over a solid crown. Physique/silhouette and the equipped harness, holster, pouches and contact remain open.

Complete body: clothing-driven masks disabled, original MPFB body coordinates retained, and opaque foundation preserved. Refitted trousers cover the previously exposed thighs in all four current views. The separate skinned preview export passes body/foundation structure checks, but contains 929,032 triangles and is 35.65 MB; runtime budget and deformation approval remain open. It contains no locomotion clips. Audits: `reference_fit/current/full_body_fit_audit.json` and `full_body_export_audit.json`.

## Next

Replace the visible helmet-like crown with separated asymmetric hair masses and fine strands, fit the adult face/profile against the reference, then build actual garment wrinkles and overlapping drape. Check all four views before exporting. Walk/run/jump/swim and equipped-item deformation must be reviewed on the resulting candidate; earlier runtime animation passes do not approve this source.

Builders: `tools/characters/rebuild_arjun_boot_panels.py`, `refine_arjun_eye_contact.py`; renderer: `render_arjun_current_fit.py -- --source WorkingAssets/Arjun/reference_fit/arjun_complete_body_fitted_candidate.blend --output docs/characters/arjun/reference_fit/current --full-only`; comparison: `compare_arjun_multiview.py --candidate-dir docs/characters/arjun/reference_fit/current --output docs/characters/arjun/reference_fit/current/reference_comparison.png` (renderer runs through Blender; comparison through the existing Pillow runtime).

## Retention and validation

Superseded captures now resolve to current evidence; source/face calibration images and useful editable rebuild inputs retained. Obsolete hair-clump backup removed after checking references; its retained replacement is the sculpted/material/eye/boot chain. Removal hashes: `reference_fit/retention_2026-10-05.json`. Earlier failures and source-retirement details: [history](reference_fit_history_2026-10-05.md).

Python compilation passes. Rendered appearance remains NOT_EXACT; no playable replacement or motion/contact approval is claimed.
