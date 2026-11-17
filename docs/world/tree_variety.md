# Tree variety and Indian species —25October2026

The world now uses a seven-form palette: original open-branched broadleaf, dense mango, spreading forest crown, young small tree, **Peepal**, **Banyan** and **Palmyra fan palm**. The three named additions are newly authored geometry, not renames of the older generic trees. All use existing tree slots; terrain/nature source scenes and save formats are unchanged.

Peepal (`Ficus religiosa`) has a branching crown and geometric heart-shaped leaves with an explicit basal notch and long drip tip. Banyan (`Ficus benghalensis`) has a wider crown, spreading limbs, free hanging roots and four grounded prop roots. Palmyra (`Borassus flabellifer`) has a tall, ringed trunk and upright/deeply segmented fan fronds. Botanical morphology references: [NParks Peepal](https://www.nparks.gov.sg/florafaunaweb/flora/2/9/2915), [NParks Banyan](https://www.nparks.gov.sg/florafaunaweb/flora/2/8/2899), [NParks Palmyra](https://www.nparks.gov.sg/florafaunaweb/flora/2/6/2602). These are usable game models; the checks below are not botanical, photorealistic or final art approval.

## Editable sources and rebuild

- `WorkingAssets/Environment/IndianTrees/{peepal,banyan,palm}.blend`: editable full geometry/materials.
- `environment/vegetation/indian_trees/{peepal,banyan,palm}_lod{0,1,2}.glb`: nine explicit near/medium/far exports; `species.json` records botanical identity and prop-root anchors.
- Rebuild: `/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/environment/build_indian_tree_species.py`. The authoring script reuses only the existing organic tube builder, without executing/rebuilding unrelated forest assets. Branch/twig seeds keep large branch and prop-root positions consistent across LODs.
- Existing mango source and gameplay reduction remain: `WorkingAssets/Environment/MangoTree/mango_tree_01.blend`, original GLB/textures and `environment/vegetation/world_palette/mango.res`. Rebuild the derived gameplay mango with Godot `--headless --path . --script res://tools/environment/build_world_tree_palette.gd`. Its51,146vertices/137,292indices replace611,829/1,644,999 source data for common palette rendering; original sources remain.

## World integration

`world/suryagarh/tree_variety.gd` runs after original root repair and before render-record compaction. World-root hashing selects the palette form deterministically; scale/orientation variations remain. Named trees use shared imported meshes, geometry-defined leaf silhouettes, shared bark textures, leaf wind and generated mesh LODs. Their explicit authoring LODs remain available for asset editing/replacement. The current common render mesh uses authored LOD1 plus generated mesh LODs.

Selection weights are20%original/20%mango/15%spreading/15%young/15%Peepal/6%Banyan/9%palm before terrain suitability. Banyans are replaced by Peepal when any actual prop foot cannot meet terrain within the embedding tolerance. Thus Banyans occur at suitable level sites, rather than floating on steep slopes. Their separate prop cylinders share the original tile trunk body; the open space between trunks remains walkable. No physics-body limit increase is needed. The shared profiler fills empty low-detail woody bands by measuring triangle edges, preserving solid wood where no vertex lies inside a band.

Original placements, shared render-source slot IDs, colour/custom channels, tile culling and original assets remain. This palette replacement itself adds no tree population. The later [roadside shade avenue pass](roadside_shade_trees.md) adds separately validated verge trees. Save/load reconstructs the same choices. Newly added geometry changes the local tree outline, so actual vehicle clearance is checked after integration.

## Reusable verification

`python3 tools/world/run_tree_variety_check.py --review` validates all seven forms in32native fixture slots, root support, separate solid Banyan props, walkable gaps, one physical trunk owner per tile, idempotence and untouched baked source resources. It also captures temporary individual Peepal/Banyan/palm specimen views.

`python3 tools/world/run_tree_variety_check.py --world --review` starts an actual New Journey; checks both landscapes, every root, Banyan prop/soil contact and a15%base-triangle budget against original geometry; samples60frames per mode/view at Medium1280×720; and captures actual named trees plus village/hill/wilderness views. The world runner pauses only its own renderer for competing native work and restarts interrupted sample windows after warmup. Logs/captures/custom saves are deleted on exit. Procedural MultiMesh readback needs a native renderer; headless results are not used as visual/contact evidence.

Route regression: `python3 tools/world/run_rebellion_integration.py --cached --checks focused --native`. Its native landscape fixture includes the seven-form palette, actual covered-cart route clearance and real mission combat/reward/save/cleanup. The headless fixture retains its pre-existing single-tree contract because its procedural MultiMesh readback is unavailable.

## Current verification

Species authoring/import and native seven-type specimen/prop/gap checks pass. Actual-world native review passed with all 3,365 roots grounded and all Banyan props meeting soil. The three named species were also inspected in actual-world rendered views.

| Landscape | Peepal | Banyan | Palm | Total trees, all seven forms |
| --- | ---: | ---: | ---: | ---: |
| Main | 336 | 6 | 167 | 1,759 |
| Wilderness | 318 | 6 | 134 | 1,606 |

Useful world coordinates for finding examples: Peepal `(-86.1878, 3.953547, 115.4109)`, Banyan `(258.4079, 7.578212, 497.3695)`, Palm `(22.30555, 6.355586, 191.6968)`.

Combined base triangles are 60,915,808 versus 60,570,000 original (+0.571%). Bounded native Medium 1280×720 samples (60 frames per view/mode), reference → palette p50/p95 milliseconds: village 250.498/290.718 → 233.167/287.926; east 81.642/96.011 → 94.383/104.726; wilderness 130.463/152.951 → 125.185/146.956. These dynamic samples establish bounded integration evidence, not an overall speed-up. The eastern view costs more and the existing whole-world smooth-frame budget remains unmet. No final photorealistic tree-art approval is claimed.

Final native covered-cart regression PASS (43.8 seconds): seven shared tree meshes, 7,922.88 m route, zero support gaps/blocks, live police fire, four rifle kills across two waves, one-time reward, shop/save and camera cleanup. Editor import exited 0; Python source syntax and scoped whitespace checks passed. All temporary test captures, logs and custom saves were removed. Older four-form baseline results are in `docs/agent/history/2026-10-25-tree-variety.md` and do not certify the new species.

To see the new palette, freshly launch the authoritative main project and use Continue or New Journey. Existing saves do not need migration.
