# Forest system and benchmark — main-world integration (2026-09-30)

## Reference reading

The six supplied frames show a canopy made from overlapping, irregular crowns rather than evenly spaced tree columns. The strongest focal forms are old, asymmetric trunks with crooked branches, cavities and shelf fungi. Smaller trees fill the middle distance. Fallen timber, roots and rocks break up the ground plane. The floor combines shrubs, fern-like clumps, broad leaves, several grass heights and exposed soil; it is dense without becoming a continuous carpet. Openings wind through it as plausible walking corridors. Bright, soft daylight filters through the crown; restrained haze separates foreground trunks, middle vegetation and background trees. Bark, leaf, rock and soil surfaces vary at several scales. The benchmark's geometry does not yet achieve this appearance; these are asset and art-direction criteria for review.

## Existing project and reuse

- Godot 4.7, Forward Plus. `project.godot` opens `res://ui/main_menu.tscn`; no global rendering settings were changed.
- `world/suryagarh/suryagarh_world.tscn` has a baked landscape, WorldEnvironment, Sun/Moon and time system. `landscape_layout.gd` defines procedural height, slope, routes and plot clearances. `tools/world/bake_landscape.gd` produces terrain meshes, height-map collision, MultiMesh nature and simple gameplay collision. The terrain shader blends soil, grass and rock using textures, normals, slope and road masks. It is useful design precedent; the benchmark does not depend on Suryagarh's map data.
- `player/player.tscn` has a CharacterBody3D capsule, third-person camera and clearance, movement and gameplay components. The benchmark instances it unchanged and includes the GameTimeSystem it expects.
- Existing GLBs: `island_tree_02` (one three-surface mesh, about 3.4 m tall), `mango_tree_01` (four mesh parts with broad canopy and root flare), `grass_bermuda_01`, and `boulder_01`. The benchmark uses the tree and boulder meshes as provisional sources, preserving their imported materials. Mango tree proportions, forest suitability, LOD and alpha behavior still need visual review. The existing grass mesh was inspected but replaced by a clearer procedural stand-in for this review. Existing soil, grassy-rock and rock color/normal textures are reused on the benchmark ground.
- The shrine grove in `world/suryagarh/forest_shrine.gd` uses one world-scale MultiMesh with random scatter. It was left untouched.

## Scene and architecture

`scenes/forest_benchmark.tscn` is an isolated 60 × 60 m playable test with a collidable soil plane, benchmark lighting/environment, the existing player and time system, and `ForestGenerator`. The generator creates runtime-only `GeneratedChunks_Runtime/Chunk_xx_zz` children. Each occupied chunk holds MultiMesh batches by layer and imported mesh part. No thousands of MeshInstance3D nodes or permanent vegetation bake are made.

`ForestConfig` is a portable Resource. For each metre cell and vegetation layer, the generator derives a local random stream from the seed, cell and layer. Separate layer draws allow ground plants beneath canopy trees. Seeded fractal biome noise creates clusters; an explicit, feathered path polyline suppresses density along the playable corridor. Object-specific rates and Inspector density multipliers set layer abundance. Height, slope and optional biome-mask checks precede placement. Tree types share a minimum-separation rule. Generation runs over the complete area before spatial bucketing, so changing chunk size does not change positions. A map can supply terrain functions through `terrain_source`: `sample_forest_height(x,z)`, `sample_forest_normal(x,z)`, and optionally `sample_forest_biome_mask(x,z)`. Without a source, the benchmark is flat at Y=0.

The Inspector exposes seed, overall and per-layer density, chunk size, biome noise scale/threshold, height and slope limits, tree separation, scale ranges, path radius/feather, additional tree-path clearance, path points, near/medium/far distances, wind strength, shelf-fungus attachment probability, collision toggle, and terrain source. `wind_strength` now affects the procedural plant shader. Distance bands still control visibility only; real mesh LOD switching is pending.

## Planned asset and rendering interface

Each final species should provide named LOD0/LOD1/LOD2 mesh parts, materials, dimensions and a low-cost collision proxy if applicable. The generator can batch each part per species and chunk, choose inexpensive meshes for distance bands, and retain higher fidelity for nearby hero trees. Attachment sockets on hero/tree models should allow seeded cavities, moss, shelf fungi and broken branches. A reusable mask Resource can extend the current path polyline to map-specific exclusion and biome masks. The benchmark ground now blends soil, grassy soil, moss tint, leaf-litter tint and rock with world-space sampling, normal maps, macro color/roughness variation and the same path polyline as the generator. The procedural plant material supports optional albedo and normal textures, alpha cutout, double-sided leaf lighting, roughness and world-space wind weighted toward tips. Blender leaf/grass textures and authored detail maps are still needed for production use.

## Current limits and performance

Imported tree and boulder meshes are provisional; dead trees, fallen logs, shrubs, broad leaves, grass, floor plants, debris and shelf fungi use simple visible placeholders. The ground is a flat plane with a layered material, not varied geometry. Procedural shelf fungi can attach to some trunks, but there are no authored sockets, cavities or moss attachments. Benchmark SSAO helps contact, while its strength was reduced after rendered inspection. Fog remains light; it does not hide missing art. Authored LODs and true near/medium/far mesh transitions are still absent. The scene is ready to judge distribution, corridor, surface balance and draw-distance behavior, not reference-level appearance.

The 2026-09-28 benchmark inspection found 25 occupied 12 m chunks and 475 generator nodes before the extra tree-path clearance was introduced. The current benchmark contains 445 generator nodes. Instance counts included 48 island-tree canopy trees, 9 broad-canopy mango variants, 18 small trees, 4 hero trees, 720 short-grass clumps, 306 tall-grass clumps, 231 shrubs, 172 broad-leaf placeholders and 17 shelf-fungus attachments. Repeated vegetation is GPU-instanced. Simplified physics bodies are made only for trunks, rocks and large fallen logs; no grass or leaf collision is made. Final asset profiling remains necessary, especially imported tree shadow and draw-call cost. Visibility bands currently cull whole batches; they do not yet provide cheaper far meshes.

## Blender assets required

- Old asymmetric hero trees with branch irregularity, cavities, roots, shelf-fungus sockets and LODs.
- Several ordinary canopy species and medium/small trees, each with LODs and grounded origins.
- Dead/broken trees; fallen trunks and branch variants with matching low-cost collision proxies.
- Ferns, shrubs, broad-leaf plants and varied grass clumps with alpha cutout and normal/roughness maps.
- Shelf fungi, moss, root detail, leaf litter, twigs and varied rocks with LODs.

## Open and review

Open `res://environment/forest/scenes/forest_benchmark.tscn` in Godot and press **F6** to run the current scene. Walk from the west corridor entry with WASD and mouse. Inspect density inside and outside the corridor and view the tree silhouettes from ground level. Select `ForestGenerator`; expand its `config` in the Inspector to change the seed or densities, then rerun. To preview generation in the editor, enable `generate_in_editor` and change `regeneration_key`. Editor-generated children have no owner and are not saved as scene content.

Headless editor import and benchmark runtime load passed. A deterministic validation passed for unchanged seed and for chunk size 12 → 15 m. `review/corridor.png` and `review/side.png` were captured in Godot Forward+/Metal on Apple M4 and inspected. They show improved canopy enclosure and ground layering, but clear repetition in crowns and angular procedural foliage; visual approval remains open. The captures are fixed camera views, not normal-speed player movement. A separate physics sweep moved the existing Player from X=-25 to X=15 through the corridor with 469/480 floor-contact frames and no blocked travel; normal player-controlled feel and detailed foot contact remain for review.

## Files created or changed for this milestone

- `scenes/forest_benchmark.tscn`: separate playable scene, lighting, soil, player and time system.
- `scripts/forest_generator.gd`: deterministic distribution, path mask, terrain adapter, chunks, MultiMesh, selective collision and seeded fungus attachments.
- `scripts/forest_config.gd`: Inspector configuration.
- `config/benchmark.tres`: benchmark configuration instance.
- `scripts/forest_ground.gd`: shares the generator's path geometry and seed with the ground material.
- `shaders/ground.gdshader`: blended forest soil, grassy soil, moss, litter and rock with normal and macro variation.
- `shaders/foliage.gdshader`: optional cutout/normal textures, two-sided leaves, roughness and tip-weighted wind.
- `vegetation/placeholder_plants.gd`: low-poly instanced grass and leaf stand-ins.
- `review/capture_benchmark.gd`, `review/corridor.png`, `review/side.png`: repeatable Metal capture and inspected evidence.
- `README.md`: audit, reference analysis, architecture, limits and review instructions.
- Godot-generated `.uid` and screenshot `.import` metadata beside these files.

The original benchmark milestone was isolated. The following integration changes place a bounded forest in the main world without rebaking terrain or vegetation.


## Main-world integration — 2026-09-30

The main scene now contains `Suryagarh/WorldForestPatch` at world X=370, Z=-105. Its 60 × 60 m footprint spans X=340..400 and Z=-135..-75. `TerrainAdapter` supplies the existing Suryagarh height, normal and surveyed road/plot/field masks. Terrain elevations across the area are approximately 24..43 m; there is no duplicate flat floor or extra terrain collision. The forest uses the main world's existing sun, time, environment and terrain material. The benchmark's blended ground shader remains available in its separate scene.

Six nearby existing tree collider positions participate in new-tree separation. Existing baked trees and rocks remain. The adapter temporarily filters 669 old grass instances from MultiMesh buffers within the footprint because their cards appeared as black specks in the rendered view; the new instanced plant layers replace them. Original batch resources are retained and restored before regeneration or when the adapter option is disabled. The generated landscape files are not changed or rebaked. New tree candidates receive an additional 2.5 m of path clearance to accommodate broad bases and roots.

The integrated patch contains 25 chunks, 29 ordinary canopy trees, 11 broad-canopy variants, 17 small trees, 3 hero trees, 548 short-grass clumps, 242 tall-grass clumps, 199 shrubs, 151 broad-leaf placeholders, 268 floor plants and 12 fungus attachments at its current seed. The patch still uses placeholder art and visibility cutoffs rather than authored mesh LOD transitions.

To review in the main world, open `res://world/suryagarh/suryagarh_world.tscn`, run the current scene with F6, then press F4 five times from a fresh start. This selects the **Forest biome patch** review point at (344, -105), facing along the corridor. On a Mac keyboard, use Fn with the function keys if necessary. The ordinary game startup and player spawn remain unchanged. Walk forward through the stand, turn into its vegetation, and inspect the slope/root fit and camera clearance.

The full main-world scene loads and the forest validator passes. A 3 m/s manual capsule sweep reached all three corridor segments, staying grounded for 1,140/1,145 frames. `review/world_patch_validation.json` records the results. `review/world_entry.png` and `review/world_inside.png` were captured and inspected with Forward+/Metal on Apple M4. The entry is open and the patch follows terrain; angular plants, repeated crowns, bright existing world ground and root flares extending across slopes remain visible art limitations. Player-controlled camera and foot-contact approval are open. The full world reports two object leaks and one resource still in use at shutdown; the same warning occurs with this forest node removed, so it is tracked as a baseline world issue rather than a forest load failure.

Integration files:

- `adapters/suryagarh_terrain_adapter.gd`: terrain/mask bridge, existing tree spacing, reversible local replacement of baked grass.
- `config/suryagarh_patch.tres`: separate map seed, density, elevation, slope and distance settings.
- `scripts/forest_generator.gd`, `scripts/forest_config.gd`: optional map preparation, existing tree spacing and extra trunk/roots path clearance.
- `../../world/suryagarh/suryagarh_world.tscn`: adds `WorldForestPatch/TerrainAdapter`.
- `../../world/suryagarh/suryagarh_world.gd`: forest review entry and facing direction.
- `review/validate_world_patch.gd`, `review/world_patch_validation.json`: integrated placement and capsule traversal evidence.
- `review/capture_world_patch.gd`, `review/world_entry.png`, `review/world_inside.png`: main-world render capture and evidence.
- `../../docs/README.md`, `../../CODEX_HANDOFF.md`: index and current status pointers.
- This README and Godot-generated UID/import metadata document the integration.

## In-game map marker — 2026-09-30

`world/suryagarh/landscape_layout.gd` now adds **Forest grove** to `SITES` at (370, -105), the integrated patch centre. Press **M** during play to open the map. Hover over its marker or zoom in to reveal the name; click the marker to set the existing waypoint. The marker uses the current map projection and interaction system. The terrain raster remains the existing survey image; it does not depict individual generated trees or the new vegetation footprint. No forest generation or gameplay files changed for this map addition.

Verification: Godot headless confirmed the marker coordinate matches `WorldForestPatch` in the main scene. Map appearance/label readability still needs player review.
