# Historical Arjun fit studies

Superseded render captures described below were retired on 2026-10-05. Current evidence is in `reference_fit/current/`; calibration face renders are retained. The removal hashes and replacements are recorded in `reference_fit/retention_2026-10-05.json`. These historical descriptions do not establish approval.

# Arjun owner multi-view fit — 2026-10-01

Target: the preserved owner core and equipped boards in `WorkingAssets/Arjun/references/`. Their hashes are recorded in `reference_fit/manifest.json`. Body, face and clothes must be judged together in front, side, back and three-quarter views; the equipped reference also requires fitted harness, loops, holster and pouches. The old playable appearance remains rejected.

## Current candidate

Separate editable MPFB sources under `WorkingAssets/Arjun/reference_fit/`; original `.blend` and playable GLB preserved. A bounded Gaussian face key uses 60 frontal controls. The landmark projection now uses the same camera as `face_baseline.png`; an earlier camera mismatch shifted features downward and has been corrected. Nose and mouth widths move closer to the target, but frontal measurements cannot certify identity or unseen anatomy.

Surface candidate: brown-eye mapping repaired, iris/sclera visible, original cap replaced with a separate wavy crown/locks; neutral charcoal, gathered waist/sleeve creases, fuller trouser drape. Hidden trousers are constrained inside the kurta and boot shafts after rendered penetration caused jagged edges. Core preview contains no added carrying belt; equipped accessories remain a separate fit task.

Evidence: `reference_fit/{face,front,side,back,three_quarter}_surface.png`, `surface_manifest.json`, `manifest.json`. Source: `arjun_multiview_surface_candidate.blend`. Baseline frontal normalized landmark RMS 0.086; latest surface measurement 0.0767 iris distances (earlier repaired-eye render 0.0738). Nose width target/model 0.504/0.501; mouth 0.744/0.782; face 2.215/2.320. These values are detector estimates and are not a likeness approval. The final residual fit reduces RMS to 0.0714 (about 17% below baseline); face width target/model 2.215/2.254, mouth 0.744/0.762, nose 0.504/0.486, eye width 0.459/0.442. The visible identity and hair still fail an exact-match claim.

Residual source: `WorkingAssets/Arjun/reference_fit/arjun_multiview_residual_candidate.blend`; evidence `reference_fit/{face,front,side,back,three_quarter}_residual.png`, `residual_manifest.json`, and `reference_comparison.png`.

## Open / next

2026-10-01 drape/boot study: `WorkingAssets/Arjun/reference_fit/arjun_drape_boot_candidate.blend`, built by `tools/characters/refine_arjun_drape_boots.py`. Four fresh studio views and manifest are in `reference_fit/drape_boots_2026-10-01/`. Fine trouser corrugation was rebuilt as broader diagonal gathers, with shallow front wrap layers; boot shafts now have flat crossing leather strips, outside rectangular buckles and an outsole welt. All four views were visually inspected. **NOT_EXACT**: trouser volume still reads as two rounded legs and the wrap boundaries look like thin surface seams; boot bands still bulge like ropes in front/back views and the vamp straps lack consistent visible contact. Do not promote this candidate. Next replace the patch-like wrap with a continuous asymmetric draped garment and fit the straps directly to the shaft surface. Face/hair/body remain the residual candidate and still fail likeness; equipped attachments and motion/contact have not been validated on this source.

Face identity, jaw/profile depth, brow/moustache density, wavy-hair silhouette, skin detail and clothing drape still differ visibly. Final physique/silhouette comparison and equipped harness/holster/contact remain open. Candidate renders and numeric improvements must not be described as an exact match. No candidate from this work has replaced `characters/arjun/arjun.glb`; no new motion or full-world approval is claimed.

Reproduce with `render_arjun_reference_face.py`, `measure_arjun_reference_face.py`, `build_arjun_reference_fit.py`, `refine_arjun_reference_surface.py`, and `refine_arjun_face_residual.py` in `tools/characters`. Measurements require the existing local FaceLandmarker runtime/model; Blender builders remain separate from runtime exports.

## Rendered comparison outcome

`reference_fit/reference_comparison.png` shows all four owner views above the residual candidate. **VISUAL_MATCH_FAILED / NOT_EXACT**: the face still reads younger/smoother, the hair forms a short shell rather than the fuller tousled waves, the shirt lacks the reference's dense lived-in folds, trousers still read as separate balloon legs rather than overlapping diagonal drape, and boots lack the layered straps/last detail. Fix those source shapes before runtime replacement or equipped fit. Body proportions/pose require another silhouette pass; the frontal landmark score is only one diagnostic. The second fit and polar hair seam correction were rendered in all four views; the final measured RMS is 0.071395. Original sources/reference hashes and runtime GLB are preserved.

## Continuous-drape experiment — rejected

`reference_fit/continuous_drape_2026-10-01/` and `WorkingAssets/Arjun/reference_fit/arjun_continuous_drape_candidate.blend` preserve a failed fold/contact experiment. Front render inspection shows lumpy trousers and straps partly buried in the boot shell. **VISUAL_MATCH_FAILED**; do not use as the next export. Builder: `tools/characters/refine_arjun_continuous_drape.py`. Next requires denser drape topology with actual overlapping folds and straps projected onto the evaluated boot surface; smooth analytic radial waves have not reproduced the reference. The owner requirement remains a matching body, face, hair and outfit across all views; this work has not achieved it.

## Dense garment / projected strap pass

`tools/characters/refine_arjun_projected_drape.py` builds `WorkingAssets/Arjun/reference_fit/arjun_projected_drape_candidate.blend`. Four views and a comparison are in `reference_fit/projected_drape_2026-10-01/`. The trouser mesh is rebuilt with 129 by 192 samples per leg, narrow diagonal ridges and ankle gathers. 2,656 strap vertices are projected onto evaluated boot geometry; inward normals are corrected before an outward 4.5 mm offset. The offset residual is a construction diagnostic, not contact or deformation approval. Front/side/back/three-quarter inspection confirms straps are visible again and the large trouser lumps are removed. Fold spacing remains too regular, boot crossings/edges are bulky and some vamp edges look fragmented. **NOT_EXACT**, no runtime export.

A separate hair-wave study uses `tools/characters/refine_arjun_hair_clumps.py`, source `arjun_hair_clump_candidate.blend`, evidence `reference_fit/hair_clumps_2026-10-01/`. Thick glossy waves failed the first render; the next revision reduces thickness, count and shine. Face/body are unchanged in both studies. The remaining face, hair silhouette, garment cut/overlap, wear and equipped fit still require work before any match claim.

Final hair revision rendered and inspected in all four angles: 180 tapered waves, 1.3 mm curve radius, higher roughness. Gloss reduced, but sparse loop-like waves still sit on a cap silhouette, especially side/back. **VISUAL_MATCH_FAILED** remains. `hair_clumps_2026-10-01/reference_comparison.png` records the latest complete comparison. Python compilation and docs gate pass; no motion/contact or identity approval implied.

## Flattened-lock hair study

`tools/characters/refine_arjun_sculpted_hair.py` builds `WorkingAssets/Arjun/reference_fit/arjun_sculpted_hair_candidate.blend`; four views and comparison are in `reference_fit/sculpted_hair_2026-10-01/`. Replaces circular loops with 480 closed flattened tapered locks and a new crown. Second render increases crown/front volume, lowers front edge, varies lock sweep and reduces shine. All four angles inspected: loose loops removed, but solid helmet form and repeated ridges still fail the tousled reference. **VISUAL_MATCH_FAILED**. Next replace the continuous visible crown with separated asymmetric lock groups and irregular silhouette gaps, then revisit face/profile. Body/face/clothes unchanged from the projected-drape study; no runtime export or motion approval. Python compilation passes. Final shared handoff docs gate passes; this does not change visual status.

## Material realism study — visual failure

`tools/characters/refine_arjun_material_realism.py` builds `WorkingAssets/Arjun/reference_fit/arjun_material_realism_candidate.blend`. Evidence: `reference_fit/material_realism_2026-10-01/`; close-ups use `tools/characters/render_arjun_realism_details.py`. Adds crossed cotton warp/weft microbump, shallow directional crumpling, lower mottled-colour contrast, fine leather grain and skin pore bump. Crown recessed 2 mm under the locks. First render made shirt/sash too pale through sheen; revised dark charcoal and reduced sheen restore the target palette in full-body renders. These changes preserve body/face/garment proportions, so exact likeness and fold construction remain unresolved. No runtime export or animation approval.

Face close-up `material_realism_2026-10-01/face_detail.png` reveals molded hair strips, distorted iris mapping and flat moustache. The pore shader does not establish realism. These are larger visible failures than the fine material detail; next fix eye geometry/iris mapping, strand-based facial hair and separate crown lock masses. **VISUAL_MATCH_FAILED** remains; do not promote.

## Known close-up corrections

`tools/characters/correct_arjun_eyes_moustache.py` builds `WorkingAssets/Arjun/reference_fit/arjun_eye_moustache_candidate.blend`; evidence in `reference_fit/eyes_moustache_2026-10-01/`. Replaces distorted image projection with circular procedural brown irises/pupils on the existing eyeball surface. Removes the fused thick moustache and projects finer tapered strands onto the evaluated upper-lip skin. First close-up confirms duplicated iris artifacts removed and individual hairs visible, but moustache coverage was too thin; second revision increases coverage/length. Floating gold sash-wire geometry hidden and its colour pattern moved into the cloth shader. Current revision renders face, three-quarter face and sash/torso for visual review. These fixes do not solve head identity, eyelid shape, hair helmet form or garment drape; exact match remains open. No runtime export.

Latest face/three-quarter/torso renders confirm circular irises and finer moustache strands; denser moustache still had a rectangular outline, so outer height is tapered in the boot-contact successor. Sash wires are absent in the torso close-up, though the procedural pattern remains overly regular. Cloth still appears too smooth: material nodes alone have not produced convincing reference wrinkles.

`tools/characters/correct_arjun_boot_strip_contact.py` builds `WorkingAssets/Arjun/reference_fit/arjun_boot_contact_candidate.blend`; boot front/side and successor face evidence in `reference_fit/boot_contact_2026-10-01/`. Changes nearest-point projection to directional rays and reduces leather offset/thickness. First render still showed fragmentation: projection used the evaluated posed shell and armature then deformed the straps again. Revision builds the projection tree with the shell armature temporarily disabled, restores it before rendering, and retains skinned strips. Render review remains required; projection counts are not contact approval.

Boot successor also tapers outer moustache height; close-up shows a narrower outer outline, while full reference moustache likeness remains open. Boot rest projection alone did not remove fragmentation: strip weights were single-bone while shell blends foot/calf by `(z-.145)/.13`. Latest revision assigns the identical blend to every projected strip vertex and uses 3 mm surface clearance. Final boot front/side review still shows vamp fragmentation and gaps; **VISUAL_MATCH_FAILED**. Do not promote. Rest projection and matched weight blends did not resolve the visible failure; next rebuild the vamp straps as continuous fitted pieces with render-resolution surface contact, remove duplicate buckles and check sole silhouette.

## Source retention — 2026-10-05

The superseded `arjun_drape_boot_candidate.blend`, `arjun_continuous_drape_candidate.blend`, and `arjun_hair_clump_candidate.blend` files were removed after the source audit. Their unsuccessful visual findings above remain historical results. The rejected-study builders were retired on 2026-10-07; their retained residual/projected-drape inputs and the later sculpted/material/eye/boot source chain remain. Inventory and removal hashes: `docs/assets/source_retention_2026-10-02.json`.
