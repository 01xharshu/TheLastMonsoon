# Ruined hill fort — current integration, 2026-10-06

Status: integrated in the main Suryagarh world as `OldFort`, at `(520,120,-350)`. The playable footprint is 120 × 100 m; the shared landscape grades the surrounding hillside and access trail. Embedded mode does not add a second ground mesh. The standalone scene remains available for focused iteration.

Five zones rise approximately 8 m from approach to keep. Central, west and east paths weave between broken walls, intact/damaged/collapsed arches and 28 cover pieces. Navigation is saved offline; the latest bake contains 1,224 polygons.

## Current realism and movement batch

- Peripheral rocks now use the native landscape height outside the fort footprint, with buried bases.
- Replaced box vegetation with 240 clustered grass tufts in a single MultiMesh.
- Crate cover has separate board and strap details.
- CoverPoint and peek markers are at foot height; CoverPoint markers expose the `fort_cover_points` group and cover normal/type metadata.
- Added four keep access steps and a west climb shortcut with eight projecting hold rows and a supported wall walk. It uses the existing player climb system and its animation transitions; no shared character animation files were changed.
- Embedded loading skips unnecessary temporary terrain generation when saved navigation exists.

## Evidence and limits

`tools/world/validate_fort_features.gd`: **PASS** for 28 ground-level markers, supported climb landing and 240 grass instances. `tools/world/bake_fort_navigation.gd`: **PASS**, 1,224 polygons. These checks do not establish normal-speed jump/catch/mantle contact or full flank traversal.

[Main-world Metal/Forward+ overview](captures/ruined_fort_in_world.png) freshly captured and inspected on 2026-10-06. It confirms hillside placement and grounded peripheral scenery. The fort still visibly reads as a sparse blockout; masonry remains rectangular and peripheral boulders too rounded. The screenshot predates the final crate board additions in this batch.

The capture reached `SURYAGARH READY` and saved successfully, but shared-world errors were logged in `systems/world_audio.gd`, `cantonment_workplaces.gd`, `civic_missions.gd` and `cart_mud_effects.gd`. This is not a clean full-world runtime pass.

## Exact next work

Develop chipped stone modules and denser ruined interiors, reuse detailed period props, improve rocky silhouettes, inspect all three routes at player height, run actual climb/cover transitions at normal speed, then add the fort combat encounter/objective using existing full-body MPFB actors and their AnimationTrees. Measure cover gaps, sightlines and performance afterward. Final realism, historical approval and an actual 8 GB device test remain open.
