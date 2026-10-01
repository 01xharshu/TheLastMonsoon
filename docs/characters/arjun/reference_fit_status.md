# Arjun owner multi-view fit — 2026-10-01

Target: the preserved owner core and equipped boards in `WorkingAssets/Arjun/references/`. Their hashes are recorded in `reference_fit/manifest.json`. Body, face and clothes must be judged together in front, side, back and three-quarter views; the equipped reference also requires fitted harness, loops, holster and pouches. The old playable appearance remains rejected.

## Current candidate

Separate editable MPFB sources under `WorkingAssets/Arjun/reference_fit/`; original `.blend` and playable GLB preserved. A bounded Gaussian face key uses 60 frontal controls. The landmark projection now uses the same camera as `face_baseline.png`; an earlier camera mismatch shifted features downward and has been corrected. Nose and mouth widths move closer to the target, but frontal measurements cannot certify identity or unseen anatomy.

Surface candidate: brown-eye mapping repaired, iris/sclera visible, original cap replaced with a separate wavy crown/locks; neutral charcoal, gathered waist/sleeve creases, fuller trouser drape. Hidden trousers are constrained inside the kurta and boot shafts after rendered penetration caused jagged edges. Core preview contains no added carrying belt; equipped accessories remain a separate fit task.

Evidence: `reference_fit/{face,front,side,back,three_quarter}_surface.png`, `surface_manifest.json`, `manifest.json`. Source: `arjun_multiview_surface_candidate.blend`. Baseline frontal normalized landmark RMS 0.086; latest surface measurement 0.0767 iris distances (earlier repaired-eye render 0.0738). Nose width target/model 0.504/0.501; mouth 0.744/0.782; face 2.215/2.320. These values are detector estimates and are not a likeness approval. The final residual fit reduces RMS to 0.0714 (about 17% below baseline); face width target/model 2.215/2.254, mouth 0.744/0.762, nose 0.504/0.486, eye width 0.459/0.442. The visible identity and hair still fail an exact-match claim.

Residual source: `WorkingAssets/Arjun/reference_fit/arjun_multiview_residual_candidate.blend`; evidence `reference_fit/{face,front,side,back,three_quarter}_residual.png`, `residual_manifest.json`, and `reference_comparison.png`.

## Open / next

Face identity, jaw/profile depth, brow/moustache density, wavy-hair silhouette, skin detail and clothing drape still differ visibly. Final physique/silhouette comparison and equipped harness/holster/contact remain open. Candidate renders and numeric improvements must not be described as an exact match. No candidate from this work has replaced `characters/arjun/arjun.glb`; no new motion or full-world approval is claimed.

Reproduce with `render_arjun_reference_face.py`, `measure_arjun_reference_face.py`, `build_arjun_reference_fit.py`, `refine_arjun_reference_surface.py`, and `refine_arjun_face_residual.py` in `tools/characters`. Measurements require the existing local FaceLandmarker runtime/model; Blender builders remain separate from runtime exports.

## Rendered comparison outcome

`reference_fit/reference_comparison.png` shows all four owner views above the residual candidate. **VISUAL_MATCH_FAILED / NOT_EXACT**: the face still reads younger/smoother, the hair forms a short shell rather than the fuller tousled waves, the shirt lacks the reference's dense lived-in folds, trousers still read as separate balloon legs rather than overlapping diagonal drape, and boots lack the layered straps/last detail. Fix those source shapes before runtime replacement or equipped fit. Body proportions/pose require another silhouette pass; the frontal landmark score is only one diagnostic. The second fit and polar hair seam correction were rendered in all four views; the final measured RMS is 0.071395. Original sources/reference hashes and runtime GLB are preserved.
