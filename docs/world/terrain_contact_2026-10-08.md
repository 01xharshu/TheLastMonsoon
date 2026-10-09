# Terrain, road contact and grass — 2026-10-08

The authored grass is integrated in main; see [grass integration](grass_main_integration_2026-10-06.md) for the exact Bermuda before/after, shared core/detail blades, rooted placement and measured cost. This pass preserves that system and fixes the upper fort-road junction rather than replace main with the older terrain worktree.

## Road defect and repair

The descending trail's grading was applied after the higher switchback grade. Their corridors overlap near (486,-251), tilting the switchback's walking strip sideways: the initial audit measured a 57.79% cross-grade. Merely suppressing the descending corridor made its own approach too steep, so that intermediate design was rejected before baking.

The final repair eases the last four upper-trail grades into the switchback and protects the access strip from the descending corridor's outer grading. The route coordinates, junction endpoint and fort entrance remain unchanged. The existing plot/lane bound-cache optimization was preserved.

Only terrain tile `09_04` was rebuilt, including its actual HeightMap collision. Its boundary heights changed by exactly 0 m. Five existing tree/rock instances were shifted vertically to retain ground support (largest adjustment 1.389 m); horizontal positions, rotation, scale and associated rock-body grounding were retained. Grass was re-rooted against the rebuilt triangle mesh. Other tiles, current settlements, cultivated plots, crop cover and authored sites were retained.

This remains a fictional cut-and-fill earth approach, not an authenticated reconstruction of a particular 1857 mountain road. Period/context limits remain in [historical accuracy](historical_accuracy.md).

## Evidence and acceptance

- [Before route audit](terrain_before_2026-10-08.json): original tilted strip.
- [Final baked-surface audit](terrain_routes_2026-10-08.json): 12,003 centre/shoulder samples, no missing support or grades above the review threshold. Access cross-grade 10.35%, longitudinal 7.51%; upper trail cross-grade 27.70%, longitudinal 30.04%. Worst rendered/physical height difference 11.49 mm on the wider fort trail; it remains within current terrain tolerance.
- [Patch report](fort_road_patch_2026-10-08.json): one tile, unchanged boundary, rooted nature retained. Bake 6.598 s; no new simulation nodes or mesh density were introduced.
- Current actual Metal pixels: [walking strip](captures/terrain_2026-10-08/after_walk.png), [cut and junction](captures/terrain_2026-10-08/after_cut.png). These use the real generated landscape at 1280 × 720, with fixed camera/light fixtures. The walking strip now sits on a continuous terrain surface; exposed hillside banks remain visible as cut ground.
- [Real-controller evidence](road_walk_2026-10-08.json) passes headless and Metal: all three uphill/downhill/junction routes reached their destination, with zero airborne frames and no jump input. [Continuous switchback walk](captures/terrain_2026-10-08/road_walk_1x.mp4) is 4.4 s at 1x simulation rate (60 Hz physics, sampled at 10 fps), 1280 × 720; other actors are paused. Inspected mid-walk frames show terrain support; the existing clothing/animation is not approved by this terrain pass. The first fixture used a foot-origin assumption for the centred 1.8 m capsule, causing an invalid buried spawn; its fall results are rejected and the fixture uses the actual capsule clearance on rerun.

Current captures demonstrate terrain form, not final historical art approval. Isolated grass profiling does not establish whole-game FPS: main before/after medians remain about 6.9 ms under desktop presentation, Metal GPU timing returns zero, and added small batches cost more draw submissions. Whole-game cost belongs in the runtime optimization evidence.

## Ownership and reproduction

Terrain owns `grass_blades.gd`, the grass shader, grass bake/refresh and this local road grading repair. Household kits own cultivated plots, banks, household vegetation and their seasonal art; cantonment/building owners own military architecture, occupants and service routines. This pass adds no humans and changes no MakeHuman/MPFB bodies, foundations, uniforms, AnimationTrees or controller implementation.

Run `tools/world/bake_landscape.gd -- --fort-road-patch` on Metal for the bounded road update. `--grass-only` refreshes foliage without replacing concurrent terrain/site work. Run `tools/world/audit_terrain_routes.gd`, `tools/world/capture_road_transition.gd` and `tools/world/validate_road_walk.gd` for surface/render/player evidence.

Native fixture uses the standard SaveManager shutdown and completed without script/exit errors. The standalone tile bake emitted two ObjectDB exit-leak warnings; they are recorded as a tooling cleanup limitation, not hidden as a game pass.

Grass budget note: the integrated core/detail transform buffers contain 1,262,136 records (57.78 MiB raw transforms), versus 427,375 Bermuda records (19.56 MiB). This buys the narrow blade silhouettes and near detail at a real memory/submission cost; desktop frame timings do not prove spare target GPU budget. Keep this cost visible in further density work.
