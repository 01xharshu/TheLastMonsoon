# Private woman skirt deformation study — 2026-10-01

Status: IN_PROGRESS. Scope: isolated editable Blender and Godot candidate; live rank assets unchanged.

## Source and implementation

The existing `Companion gathered skirt` has 4,752 pelvis-only vertices and no correctives. The isolated source adds four lower-skirt morphs: StrideLeft, StrideRight, LagLeft, LagRight. The upper 1,152 vertices are pinned exactly. Stride displacement is at most 37.11 mm; lag displacement at most 30 mm. The MakeHuman body vertex coordinates are checked unchanged. These are authored secondary motion shapes, not a cloth simulation or a completed sitting fit.

- Source: `WorkingAssets/NPCs/british/private_pair/private_pair_mpfb_candidate.blend`
- Candidate: `WorkingAssets/NPCs/british/private_skirt_candidate/private_woman_skirt_candidate.blend`
- Candidate GLB: `characters/npcs/british/candidates/private_woman_skirt_candidate.glb`
- Hashes and displacement/pinning evidence: `docs/characters/british/candidates/private_skirt_candidate.json`
- Driver: `characters/npcs/british/candidates/private_skirt_actor.gd`; same personal AnimationTree and gait phase, 0.12-second exponential relaxation when walking stops. Only the isolated fixture uses this driver.

## Reproduction

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/characters/build_british_skirt_candidate.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/characters/export_british_roster.py -- private --skirt-candidate
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --fixed-fps 60 --script tools/characters/validate_british_skirt_candidate.gd
```

## Remaining gates

Inspect imported morphs and fresh movement captures; assess close body/skirt clearance, waist closure and hem/sole contact. Run and seated entry/idle/exit have no completed British gameplay clips or garment correctives. Retained foundation coverage and the full base-body/clothing acceptance matrix remain open. Do not propagate this secondary-motion study to other ranks or replace the live wardrobe until those fitting gates are met.

## First review and repair

The first Metal side capture showed a protruding back waistband edge. The isolated source now fits the separate waistband to interpolated skirt/bridge rings with 2.5 mm clearance. The complete 750-frame headless import/morph/settling check passed before this band repair; rerunning after export is required. The first Metal run produced frames 30, 190 and 260 but ended before its final report.

## Final result of this pass — 10:37 IST

- Repaired candidate export imported and completed the full 750-frame Metal Forward+ fixture on Apple M4, exit 0. `candidates/skirt_motion_validation.json`: all four morphs activated; stride peaks 0.7723/0.7721, lag peaks 0.3475; after 90 idle frames the residual vector length is 0.00000286.
- Fresh Metal frames `candidates/skirt_motion_30.png`, `skirt_motion_190.png`, `skirt_motion_260.png`, `skirt_motion_610.png` were generated; side 260 and walking 610 were inspected after the band repair. The rear waist transition still has an abrupt silhouette. The skirt retains a broad bell and needs further tailoring; these secondary morphs do not establish realistic fabric motion.
- Original source hash remains `4c7d15b0c74648d3a21395911fb9f151500327b8a907cd9f19f1eb75d7fc5fd3`; live Private man/woman GLBs have no diff from HEAD. Candidate hashes are refreshed in `candidates/private_skirt_candidate.json`.
- `python3 tools/check_agent_docs.py` and `git diff --check` pass.

Exact next action: refine the candidate bridge profile against the retained body to remove the back waist ledge; repeat front/side/rear walking and turning clearance review. Then author/run the missing run and seated entry/idle/exit fitting cases before any live migration or rank propagation. Task remains IN_PROGRESS.

## Applied for now — owner request, 1 October 10:41 IST

Owner instructed: “Apply it for now, and we'll move to next.” Application milestone COMPLETE. The candidate GLB is installed at `characters/npcs/british/private_woman.glb`; `british_npc_roster.gd` selects the skirt actor driver for PrivateWoman. Other ranks retain their existing models/drivers. The original pair source remains recoverable; the isolated skirt source is now the current woman export source. The standard Private pair exporter respects the applied flag when choosing that source.

`validate_british_skirt_candidate.gd -- --live-roster` completed 750 frames using the actual roster-spawned PrivateWoman, morph/settling PASS. `validate_british_animation_tree.gd` passed for all 16 actors. The applied GLB hash matches the previously reviewed Metal candidate. No fresh full-world movement claim is made from the isolated roster exercise.

Owner deferred the remaining back-waist silhouette, cloth/body clearance, run and seated fitting work. The next British rank for continuation is Corporal; retain these deferred issues for later tailoring rather than reopening them as an application blocker.

## Corporal continuation — IN_PROGRESS

Build first stopped because Corporal has no separate gathered waistband. No candidate was saved and export was unavailable. Source inventory confirms the fitted transition/skirt/body are present. Builder now treats a separate band as optional, preserving this rank construction. Next rebuild and export the Corporal candidate, then verify/import and review.

Corporal source/GLB built successfully: four morphs, 432 pinned upper vertices, maximum stride displacement 35.60 mm and lag 28.78 mm. Body coordinates unchanged. Candidate hashes are in `candidates/corporal_skirt_candidate.json`. Metal 750-frame candidate review running; live Corporal unchanged until inspection.

Corporal Metal continuous review stalled after the first capture; stopped its own process after over two minutes. Next use sampled Metal pose captures plus the complete headless 750-frame check. This does not establish continuous native playback approval.

## Corporal application complete — 10:49 IST

Applied to `characters/npcs/british/corporal_woman.glb` and the roster's CorporalWoman skirt driver. Original Corporal source and man model are preserved. Source: `WorkingAssets/NPCs/british/corporal_skirt_candidate/corporal_woman_skirt_candidate.blend`; hashes: `candidates/corporal_skirt_candidate.json`. The standard pair exporter uses this woman source while its applied flag is true.

- Complete headless candidate and live-roster checks: 750 manually evaluated 60 Hz steps, all morphs activate, residual after idle = 0.00000283. Live result: `candidates/corporal_skirt_motion_validation.json`.
- Sampled Metal pose render check PASS: `candidates/corporal_skirt_metal_samples_validation.json`, frames `corporal_skirt_motion_30.png`, `_190.png`, `_260.png`, `_610.png`. Side 260 and walking 610 inspected. Sampled stepping skips intervening rendered frames; this does not approve continuous native playback or full-world contact.
- Existing back waist ledge and broad skirt silhouette remain deferred; source body coordinates unchanged. No run/seated or final garment approval.
- All 16 AnimationTrees PASS after live installation. `git diff --check` and documentation gate PASS.

Corporal commands:
```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/characters/build_british_skirt_candidate.py -- corporal
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/characters/export_british_roster.py -- corporal --skirt-candidate
/Applications/Godot.app/Contents/MacOS/Godot --path . --windowed --resolution 1280x900 --rendering-driver metal --fixed-fps 60 --script tools/characters/validate_british_skirt_candidate.gd -- --rank=corporal --fast-review
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --fixed-fps 60 --script tools/characters/validate_british_skirt_candidate.gd -- --rank=corporal --live-roster
```

Next rank: Sergeant. Inspect its editable skirt/transition construction before adding the same restrained gait morphs; retain its own body and outfit. Builder/exporter/fixture currently support Private and Corporal, so extend the explicit rank list for Sergeant first. Preserve Private/Corporal live assets and deferred fitting issues.

## Sergeant continuation — IN_PROGRESS

Sergeant candidate built/exported from its own MPFB source, body coordinates unchanged, 432 pinned upper vertices. No separate waistband exists; original fitted transition retained. Maximum stride/lag displacements 38.31/30.97 mm. Hashes: `candidates/sergeant_skirt_candidate.json`. Next import, sampled Metal pair review and live application; prior ranks unchanged.

## Sergeant application complete — 1 October 10:52 IST

Live `sergeant_woman.glb` and roster gait driver installed. Original Sergeant pair source and male GLB retained. Standard exporter follows the applied woman source. Body coordinates unchanged; four gait morphs with 432 pinned upper vertices.

Sampled Metal pair review passed and side 260/walk 610 inspected (`candidates/sergeant_skirt_motion_260.png`, `_610.png`). Report: `candidates/sergeant_skirt_metal_samples_validation.json`. The man and woman were both manually animated with their personal trees. The waist transition remains abrupt; male crossbelt ends float in these views. These are deferred art issues, not approved cloth or contact. No continuous Metal or live-world contact approval from sampled captures.

Actual roster-spawned SergeantWoman completed 750 steps, all morphs active and idle residual 0.00000294: `candidates/sergeant_skirt_motion_validation.json`. All 16 AnimationTrees passed after installation; docs/diff gates pass.

Reproduce build/export with the same commands above replacing corporal with sergeant. Metal pair review adds `--rank=sergeant --fast-review --pair`; live-roster check uses `--rank=sergeant --live-roster`.

Next rank is Lieutenant: inspect its source construction and extend explicit builder/exporter/fixture rank lists before continuing the applied gait method. Preserve the three applied ranks and deferred fitting issues.
