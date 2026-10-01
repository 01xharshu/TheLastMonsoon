# Sergeant uniform realism — 1 October

Status IN_PROGRESS. Scope: Sergeant male uniform surface/fitting refinement, retaining MakeHuman body and the applied woman skirt. Current regiment-specific cut and equipment are still inferred concepts.

## Work

Ten crossbelt/rank-lace meshes subdivided and fitted to the evaluated outer clothing surface in rest space at 6 mm clearance, with barycentric clothing skin weights rather than a single spine bone. Source body coordinates unchanged. Raster wool grain maps persist in glTF; buff-leather/lace roughness and brass response refined. Source: `WorkingAssets/NPCs/british/sergeant_uniform/sergeant_uniform.blend`. Refit displacement/hashes: `candidates/sergeant_uniform_manifest.json`.

Historical source: [National Army Museum infantry pouch belt, c.1855](https://collection.nam.ac.uk/detail.php?acc=1977-08-25-2) describes the transition from cross straps toward pouch/waist belts. The current game's crossbelt arrangement is therefore not proof of an exact 1857 regimental uniform. This pass repairs fit/material response; regimental pattern selection remains open.

Commands:
```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/characters/refine_sergeant_uniform.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/characters/export_british_roster.py -- sergeant --uniform-candidate
```

Next import and inspect front/side/back sampled Metal movement. Check strap clearance and lace shape before runtime application. Full-speed run/seated/contact, final cut and precise historical approval remain open.

First Metal review failed: straps mostly hidden by the exported 5 mm clothing shell; generated colour maps also rendered too dark. Next rebuild with evaluated outer-shell fitting and corrected raster colour values. Live uniform remains unchanged.

Second review: straps visible but coarse two-edge topology still intersects the curved chest; texture grain looks too checkered. Rebuild subdivides accessories before outer-surface projection, transfers exact nearby triangle barycentric skin weights, uses 6 mm clearance, and reduces colour grain amplitude. No live migration yet.

Third review: chest straps substantially closer to tunic; lower ends and elbow-level rank lace still distorted. Final source pass moves lace to mid upper sleeve and constrains low belt endpoints to the torso. Next render review/application if improved.

Final sampled Metal side 260/front 610 inspected: belt ends now follow torso and upper-arm chevrons retain their placement. Applied current male GLB and live source flag. Next import/16-tree regression; final historic cut/collar, garment folds, buckles/equipment and full-speed contact still open.

## Applied result — 11:11 IST

Live male source/GLB updated, body coordinates unchanged. Four sampled Metal frames completed (30/190/260/610); side 260 and front 610 inspected after the final placement repair. Images: `candidates/sergeant_uniform_skirt_motion_260.png` and `_610.png`; sampled fixture result: `candidates/sergeant_uniform_sample_validation.json`. This fixture evaluates the pair/skirts and captures the man visually; it does not measure male garment penetration or approve continuous playback.

All 16 actual roster AnimationTrees pass after import/application. Standard `export_british_roster.py -- sergeant` retains the new male source and the applied woman skirt. Textures packed in source and embedded in GLB. Original pair source preserved.

Next: replace the donor-shirt cut with a source-authored period tunic collar/front closure, seam construction and restrained folds over the retained body; fit actual waist/pouch equipment after choosing a specific regiment/date. Then full-speed idle/walk/run/turn/seated garment-contact review before propagating uniform changes to other ranks. Uniform realism remains IN_PROGRESS; this surface/accoutrement pass is applied.
