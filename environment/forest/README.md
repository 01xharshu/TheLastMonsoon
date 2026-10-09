# Reusable forest biome — 2026-10-09

## Current scope and appearance

The 60 × 60 m benchmark and bounded main-world **Forest grove** patch are integrated. This batch replaces the previous angular foliage stand-ins and striped bark with editable Blender assets, photographed PBR materials, explicit LOD meshes, corrected chunk origins and terrain contact. It is a usable forest baseline; matching the supplied reference's ancient-tree anatomy, species diversity and dense natural composition is still an art-review requirement.

The references show asymmetric old trunks, crooked branching, cavities and fungi as focal forms, overlapping crowns, medium trees, fallen wood, fern/shrub masses, broad leaves, mixed grass heights, stones and exposed litter/soil. Corridors emerge between vegetation masses. Restrained haze and soft daylight separate foreground, middle and background. These remain composition criteria; fog is not used to conceal geometry defects.

## Project audit and retained systems

The original project inspection found Godot 4.7 Forward Plus, the main title-menu route, Suryagarh's baked terrain and HeightMap collision, procedural layout/road/plot rules, existing WorldEnvironment, Sun/Moon/time, player CharacterBody3D with UI/inventory/gameplay, imported nature assets and baked vegetation batches. The forest retains these systems. The current terrain adapter reads actual baked triangle vertices through the terrain owner's `grass_blades.gd` surface-frame helper. Existing tree positions still constrain new-tree separation. Existing ground/rock and photographed leaf-atlas inputs are reused; their originals are retained.

No player, human asset, AnimationTree, clothing, world terrain bake or global rendering setting was changed by this forest batch. Plant motion uses the foliage shader and existing WindSystem. The benchmark's own ambient-light enum was corrected (ambient was disabled), shadow bias reduced and very subtle volumetric haze enabled locally. Main-world lighting and time remain the existing world's settings.

## Architecture

- `ForestGenerator`: deterministic cell/layer RNG plus coherent density noise; height, slope, biome, layer density, tree separation, species separation and feathered polyline exclusion. Seed regeneration recreates the same placements. Chunk size changes partitioning, not distribution.
- `ForestConfig`: map-level resource for seed, density, distances, scale and masks. `benchmark.tres` and `suryagarh_patch.tres` use the same asset definitions with different map settings.
- `ForestSpecies`: per-layer replaceable near/medium/far PackedScenes, density multiplier, scale, separation, slope/height limits, extra corridor clearance, root radius, collision dimensions, terrain alignment and attachment policy.
- Each spatial chunk owns MultiMesh batches per layer, mesh surface and distance band. Instance transforms are relative to the chunk centre. LOD bands use near/medium/far bounds and small fade margins. Grass/floor debris end nearby; taller plants/ferns end at medium distance; trees/logs/rocks persist farther.
- Tree roots embed against eight sampled terrain points. Plants follow the baked slope. Logs are centred around their placement point and align to the slope; collision follows the same rotation/scale. Capsule/sphere/simple proxies are limited to gameplay-relevant wood and rocks. Leaves and ground-cover have no collision.
- Seeded shelf-fungus attachments use each tree's trunk radius and outward orientation. Hero meshes include a hollow broken-branch mouth. Bark UV phase and macro colour/dampness vary in world space. Cavities/branch anatomy still need close art review.
- `ForestFloor_Runtime`: optional bounded visual mesh follows the baked terrain, blends photographed soil/moss/litter with grass/rock detail and feathers its boundary. It adds no physical floor. Shader normals and roughness provide detail; macro noise breaks colour/roughness uniformity. Ground path rendering currently supports eight points; this patch uses four.
- Main-world grass replacement is reversible: the adapter filters existing GrassCore/GrassDetail and legacy batches only within this footprint, preserves colour/custom-data channels and restores originals before regeneration and on exit. Landscape resources are never rewritten.
- `startup_provider` is an optional loading protocol (`begin`, `checkpoint`, `finish`). The main scene supplies the existing `systems/world_startup.gd`; row/chunk checkpoints preserve the loader owner's staged startup. The portable core does not preload project-specific systems.

## Layers and sources

Editable sources: `WorkingAssets/Environment/Forest/{hero,canopy,canopy_broad,small_tree,dead_tree,fallen_log,fern,shrub,broadleaf,tall_grass,short_grass,floor,debris,shelf_fungus}.blend`.

Runtime exports: `assets/<layer>_lod0.glb`, `_lod1.glb`, `_lod2.glb` for those 14 layers. Trees use tapered, curved, connected tube rings; high-detail crowns contain individual curved leaves. Ordinary rocks reuse `assets/rock_reused.glb` from the existing boulder asset. The rock does not yet have this batch's explicit three-mesh LOD set.

Shared texture inputs and licences are recorded in [material sources](assets/textures/SOURCES.md). New CC0 materials are Poly Haven Bark Brown 02, Forest Ground 04 and Forest Leaves 02 (moss, leaves and twigs); leaf albedo/alpha, normal and roughness come from the existing Island Tree 02 photographed atlas. Materials are shared, locally VRAM-compressed and use 1K/2K inputs. GLBs omit duplicated texture payloads. Blender sources link to retained textures with relative paths; source `.blend` files are retained, superseded `.blend1` backups removed.

## Scene hierarchy

```text
ForestBenchmark
├── Ground (existing benchmark floor collision + blended material)
├── ForestGenerator
│   └── GeneratedChunks_Runtime
│       └── Chunk_x_z
│           ├── Layer_LODn_Partn (MultiMeshInstance3D)
│           └── StaticBody3D / CollisionShape3D (major wood/rocks only)
├── GameTimeSystem
├── WorldEnvironment
├── SoftDaylight
├── Player (existing scene)
└── OverviewCamera

Suryagarh (existing main world)
└── WorldForestPatch (X=370, Z=-105; 60 × 60 m)
    ├── TerrainAdapter
    ├── GeneratedChunks_Runtime / Chunk_x_z / batches and selective bodies
    └── ForestFloor_Runtime (visual only)
```

Generated children have no scene owner and are not permanently baked. Current defaults use 15 m chunks (16 chunks). The 12 m setting is also validated.

## Inspector controls

Select ForestGenerator/WorldForestPatch, then expand `config`:

- seed, overall density, every layer density (including fern), biome noise scale/threshold;
- chunk size, height range and slope limit (`1 - normal.y`, not degrees);
- tree minimum separation, tree/plant scale ranges;
- path exclusion radius, feather and additional tree clearance; edit generator `path_points` for the corridor;
- wind strength, near/medium/far distances and LOD fade margin;
- collision enable, optional near ground-cover shadows and bounded terrain-floor overlay;
- `species` list: open a layer resource to replace asset scenes or tune its placement/proxy rules;
- shelf fungus probability and tree attachment permission;
- terrain source, optional startup provider, editor generation and regeneration key.

The current corridor radius is 1.8 m with a 2.6 m feather. Trees retain extra root clearance; logs have a wider clearance. Wind strength is 0.12 for restrained motion.

## Rebuild and reuse

Run Blender with `tools/environment/build_forest_assets.py` to regenerate the sources and 42 LOD exports. Run `python3 tools/environment/fetch_forest_materials.py` to restore material inputs if needed. Existing texture/model inputs referenced by that helper are retained in the project. Offline runtime and Blender editing use the committed shared textures; downloading is not required during play.

For another Godot project, copy `environment/forest/{assets,config,scripts,shaders,vegetation}` at the same resource paths. Use ForestGenerator with a config, supply another terrain adapter if desired, and leave `startup_provider` empty unless your loader implements that protocol. Existing WindSystem is used in this project; otherwise a lightweight runtime fallback registers/drives `world_wind`. The benchmark's Player/time scene and the Suryagarh adapter are map-specific integrations, not required by the portable core. A disposable fresh-project import/generation check is provided in `review/validate_portable.gd` and the check runner.

## Verification and limits

Run `python3 tools/environment/run_forest_checks.py` for generation/LOD/node-budget and main-world corridor checks; add `--portable` for the disposable standalone-project check; add `--render` for native wind, benchmark and world render fixtures. Fixtures freeze unrelated actors while retaining collision, so they do not prove whole-world FPS or normal player-controlled animation/contact. Captures/reports/logs stay in an OS temporary directory and are deleted on runner exit. No generated test output is retained. Historical removed captures are not current evidence.

Seed regeneration and chunk-size invariance passed. At 12 m the generator has 934 nodes; at the default 15 m it has 722 with the current corridor. Ordinary canopy LODs contain approximately 20,893 / 4,642 / 959 triangles; hero 27,145 / 6,097 / 1,288. The near band retains detail; middle/far reduce geometry substantially. Small instances remain MultiMesh records rather than individual vegetation nodes. Shader cutout, shadows, overlapping fade bands and extra batches still cost GPU time; these counts do not establish target-device FPS.

The current main-world capsule check reached all three path segments with 1,139 grounded frames out of 1,145. The baked surface at patch centre is about 32.39 m. Existing grass filtering removed 5,512 core/detail records in the footprint during that check (duplicated records, not unique plants). New photographic bark was inspected close up under Metal; main-world soil winding/contact were corrected after rendered inspection. Native wind changed image pixels with a fixed-camera stationary baseline. Final Metal side, bark close-up and main-world entry/interior views were inspected with the photographic moss/litter materials and restrained wind. Small ground-cover shadows are optional; disabling them reduced the benchmark side fixture from 715 to 413 reported draw submissions and about 4.65 to 3.50 million reported primitives. Main-world entry/interior reported 882/821 draw submissions and roughly 2.94/3.02 million primitives, including the existing world. These are fixture counters, not whole-game FPS. Final art approval is open.

A live full-world render attempt encountered Metal fence timeouts in unrelated coachman cloth updates; frozen-actor forest fixtures avoid that interference. A fixture initially removed terrain collision when freezing the scene, producing false unsupported-road-flag errors; it now preserves CollisionObject3D activity. The final frozen world capture completed without script errors. An earlier benchmark capture reported five ObjectDB instances at shutdown; explicitly freeing the captured scene and allowing three cleanup frames resolved that warning in the final benchmark exit check (exit 0, no warning). Earlier full-world baseline shutdown warnings do not establish that normal game teardown is fixed.

Remaining art requirements: broader species/branch silhouettes, more distinctly ancient hero anatomy and cavities, richer fungus/moss/debris variants, further root-contact and LOD-transition review and a dedicated rock LOD set. The reference's finished appearance and whole-game frame budget are not approved by structural checks.

## Exact in-game review

1. Open `res://world/suryagarh/suryagarh_world.tscn`, press **F6**, then press **F4 five times** from a fresh start to reach the west forest entry at (344, -105). On Mac use Fn with function keys if needed.
2. Walk forward through the corridor; turn into the stand. Check bark at arm's length, photographed leaf veins, roots against slopes, fallen-log blocking, undergrowth layering and the soil/moss/litter transition.
3. Back away 25–80 m and inspect crown changes and fade transitions. Inspect actual normal-speed wind; no dense fog was added to the main world.
4. Press **Esc** and select **Map** for the current field-map UI; hover/zoom to see **Forest grove** at (370, -105). Its raster remains the existing survey, not a baked vegetation image.
5. For controlled lighting, open `res://environment/forest/scenes/forest_benchmark.tscn` and press **F6**. Changing the seed/densities in Inspector takes effect on the next run. Editor preview is optional and is never saved as generated vegetation.

## Files added/modified in this batch

- `scripts/forest_species.gd`, `forest_floor_patch.gd`, `forest_wind_fallback.gd`: replaceable asset rules, terrain-following visual floor and standalone wind driver.
- `scripts/forest_generator.gd`, `forest_config.gd`, `forest_ground.gd`: resource overrides, centred chunks/LOD bands, slope/root/log/collision rules, optional startup hooks, path/world-material synchronisation and inspector controls.
- `config/{benchmark,suryagarh_patch}.tres`, `config/species/*.tres`: map settings and 14 layer definitions.
- `shaders/{foliage,ground,bark}.gdshader`: photographed alpha-cutout/PBR maps, corrected wind UV weighting, roughness/detail blending and bark variation.
- `adapters/suryagarh_terrain_adapter.gd`: baked-triangle height/normal sampling and reversible current/legacy grass filtering.
- `scenes/forest_benchmark.tscn`: local lighting/ambient/haze and photographic ground materials.
- `assets/*_lod*.glb`, `assets/rock_reused.glb`, `assets/textures/*`, related import metadata: runtime meshes and retained shared material inputs.
- `WorkingAssets/Environment/Forest/*.blend`, `.gdignore`: editable relative-texture sources, excluded from direct Godot Blender import.
- `tools/environment/{build_forest_assets,fetch_forest_materials,run_forest_checks}.py`: reproducible authoring/material restoration and disposable-output checking.
- `review/{validate_foundation,validate_world_patch,validate_foliage_motion,validate_portable,capture_benchmark,capture_world_patch}.gd`, UID sidecars: reusable checks/capture fixtures; previous generated `world_patch_validation.json` removed.
- `world/suryagarh/suryagarh_world.tscn`: assigns the optional existing startup provider only on the forest node.
- This README, `assets/textures/SOURCES.md`, `docs/README.md`, `CODEX_HANDOFF.md`: current architecture, licences, review instructions and concise status.

Shared documentation gate: the global handoff size check is currently over its limit (80 lines / 11,694 characters at this check). The forest status is a single brief entry; unrelated live entries were preserved. This is a shared-ledger limitation, not a passing documentation gate.

## Main-world map access — 2026-10-09

`player/map_infrastructure.gd` now registers `WorldForestPatch` as **Forest grove**. The map's live authored-node collector overrides the static survey coordinate, so moving the patch also moves its destination marker. The existing map assigns the nature icon, accepts mouse selection and creates the existing in-world waypoint. Access is map-guided walking, not a new teleport system. Open **Esc → Map**, zoom/hover to find **Forest grove**, click its icon, then close the menu and follow the waypoint.

The reusable world validator now checks the live marker coordinate, nature icon category, mouse press/release selection, world waypoint and relocation sync, then walks the existing player capsule through all three corridor segments and onward to the selected map destination. PASS: destination reached within 0.3 m at approximately (370.25, -104.95), 1,680 grounded frames / 1,686. No generated test output retained. The normal player controls/animation remain unchanged.

Files changed for map access: `player/map_infrastructure.gd` (one authored-node mapping), `review/validate_world_patch.gd` (selection/waypoint/arrival check), this README and the brief forest handoff entry.
