# Village and cultivated countryside density

Updated 2026-10-11. A first rural density batch is integrated and its scoped contact/road/native checks have passed into the main Suryagarh scene. This addresses the visible dominance of grass around the western village and city approach. It does not establish completion of the wider forest, mountain or ruins composition.

## Placed land use

- Sixteen additional village houses: twelve on two facing western rows at X −452/−476, Z 174…324, and four along the edge at Z 135. Bhairavpur now has 49 houses across the original construction and this extension.
- Nine farm houses in three clusters centred near X −570, Z 80/−95/−240, with one open grain shed per cluster.
- Twenty-four 42 × 30 m cultivated plots (30,240 m²): eighteen planted plots and six worked fallow plots. Crops use shared MultiMeshes; soil, raised boundaries and paths follow the saved terrain triangles.
- Sixty-six trees in four small shelterbelts. These reuse the forest owner's canopy geometry, photographed materials, wind shaders and three separate LOD meshes. Chunk bounds are local; trunk collision persists beyond visual fading.
- Five connected lane polylines join the new village quarter and farm track to existing village streets and the city approach. Both maps draw these paths and house footprints from cached shared density data; minimap placement and tutorial/waypoint behavior are preserved.

The city remains owned by its existing district module. Six early city-edge candidates were removed because concurrent college-street expansion occupied that space. The current main-world review loads 26 through houses in that separate module; its acceptance and documentation belong to the city owner.

## Construction and rebuild

`world/suryagarh/generated/countryside_density.scn` is the active static runtime export. Its editable construction inputs are `world/suryagarh/settlements/countryside_density.gd`, `tools/world/bake_countryside_density.gd`, `tools/world/density_ground.gd`, the existing settlement construction/roof helpers and the retained forest/household assets. No human assets were created or duplicated.

The bake samples actual saved terrain triangles. Solid footings extend down to the lowest house corner; supported approaches meet the raised entrances. Roof variants reuse tile, thatch and earth-terrace construction. Nested prop instances are flattened during export to avoid orphaned imported nodes on load/exit. Static geometry is merged by material; runtime crops/trees use visibility ranges and forest LOD. This addition has no autonomous per-frame update loop.

Native rebuild from repository root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/world/bake_countryside_density.gd
```

This incremental bake preserves saved terrain geometry and other districts. It clears nature only in the authored footprint and updates the shared material's external `density_mask.res`. Red identifies cultivated plots; green identifies packed-earth paths. The terrain shader uses that mask beneath overlays so terrain LOD cannot reveal grass through fields or lanes. Full landscape rebuilds also preserve the mask and use shared footprint exclusion.

## Verification and limits

The current full-world native review found 25 rural houses, 24 fields and 66 shelterbelt trees, with 4,517 capsule clearance samples finding no new obstruction along surveyed western roads. Village and farm views were inspected in the real world. The current material/export also passed a native incremental rebuild with clean exit. The final native isolated follow-up also passed road clearance and clean exit; the packed-earth village lane and farmland views were inspected after repairing the mask. Its 26.8 ms median / 30.5 ms p95 sample excludes the populated world and is not whole-game FPS approval. The final saved export passed moving-capsule traversal through all 25 approaches and entrances. That headless fixture emitted a Jolt job-capacity warning while loading/simulating the complete saved landscape; it is recorded as a remaining physics-capacity diagnostic, not suppressed or described as a clean diagnostic run. No traversal failure or script/engine error was reported.

A native full-world timing sample at a 3600 × 2260 viewport, 0.477876 3D scale (approximately 1720 × 1080), measured 70.3 ms median and 185.8 ms p95. This is a failing performance gate. No causal attribution to this batch or whole-world FPS acceptance is claimed. Broad startup/CPU performance remains assigned to its existing owners. Roof/ground contact refinement, richer yard/interior detail, ordinary player-controlled review and final art acceptance remain open. Shelterbelts are not a completed dense forest biome or species approval.

Reusable checks (stdout only; runner owns and removes temporary screenshots on every exit):

```sh
python3 tools/world/run_countryside_density.py --isolated --contact-only
python3 tools/world/run_countryside_density.py --views-only --inspect
```

The first checks all new approaches with a moving physics capsule and checks road obstruction in the saved landscape. The second loads the actual populated world for native appearance and timing; `--views-only` deliberately skips entrance traversal. Engine errors make the runner fail even if Godot returns exit code zero. No test screenshots, recordings, logs or generated reports are retained.

## In-game review

From Bhairavpur's western lane at X −374, walk west along Z 155 into the new quarter at X −464. Walk the lane north to Z 342 and return by the connected original village lane. Enter houses from their ramps and confirm the central doorway stays clear. The four houses on the opposite edge are at Z 135. Continue west to the farm track at X −570; follow it past all three house/shed clusters and the fields. Its southern link at Z −284 returns east to the city gateway. Inspect the western tree belts and the belt beyond the far end of the new village lane, including LOD transitions during approach and retreat.
