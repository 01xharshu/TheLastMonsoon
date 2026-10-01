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
