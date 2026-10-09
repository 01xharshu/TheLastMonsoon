# Off-road and riverbank grass — 9 October 2026

Integrated in the playable main checkout. Deterministic habitat weights raise existing narrow curved blades in dry riverbank patches and uncultivated road verges. Heights vary up to approximately 1.7 m at the tallest near-detail tips, with shorter gaps and wider bending tussocks. Cultivated fields keep short ground cover. Centres remain at least 6.5 m from road centre lines; building/plot exclusions and terrain triangle rooting remain in force. Grass has no collision, so tall patches are traversable. Wind displacement grows gently with stalk height.

This grass-only bake retains current terrain, roads, rocks, tree placement and all newer settlements. Existing broadleaf trees include 195 instances within 5–80 m of the riverbank; their current runtime trunk/grounding repair remains intact. No tree-owner assets or human assets changed. This is habitat art direction, not a botanical species reconstruction.

Native Metal review: 631,017 tufts, including 19,495 tall bank and 8,825 tall off-road tufts (vertical scale greater than 2.5). Road-centre exclusion check passed. Close and wide native views inspected; the first thin-stalk result was widened before final review. The initial height-only change added no instances. The subsequent density pass doubles total instances; geometry and screen coverage increase, while shared meshes and no per-blade simulation are retained. Whole-game performance and owner art approval remain open.

In-game: walk along the river near x=47, z=161 and the uncultivated road verges. Look for irregular tall patches among short grass, bending tips, grounded roots and trees. Walk from the road into the grass; the grass should permit movement while tree trunks remain solid.

Reusable native review: run Godot with `--path . --script tools/world/review_tall_grass.gd -- --output=<OS temporary directory>`. Inspect its close/wide PNGs and delete the temporary directory afterward. Test media/reports are not retained.

## Wind and vehicle response

`GrassMotion` publishes four shared local wake emitters from the nearest registered carts (horse carts, family coaches, live travel carts and bullock carts). Movement speed controls bending; parked carts produce no sustained deformation, and stopping lets the grass recover exponentially. Vehicle teleports do not produce a new kick. The shader pushes tips outward within 8 m, reduces response across height differences, and keeps UV-zero roots fixed. This is temporary visual deformation, not permanent crushed vegetation. The existing wind field supplies independent gust sway. No blade nodes or grass collision were added.

Native Metal controlled movement check at fixed 60 Hz: emitter strength reached 0.66660 while the group-registered test stimulus moved, then decayed to 0.000672 after three seconds stationary. Rest, vehicle-bend and wind views inspected; nearby blades changed while roots stayed planted. Review uses a moving Node3D stimulus through the real cart group/manager, not a rendered cart journey. Populated-world vehicle driving and whole-game performance remain open. Terrain patches now use deterministic fractal noise with smaller height variation instead of repeated sinusoidal bands.

## Density and placement rules

Density candidates increased from 128 to 384 per 18 m square. Native bake result: 1,271,970 tufts versus 631,017 previously (2.02 times). Accepted growth uses coherent habitat noise, with thicker bank/verge patches and sparser cultivated margins. Reject centres inside surveyed plots or within 10 m of their edge, on any registered road within 6.5 m of its centre line, in cultivated interiors (field mask greater than 0.45), at elevations below 1.8 m or above 95 m, and on baked terrain whose normal Y is below 0.78. Roots follow the actual rendered triangle, not a guessed flat surface. Building plots must be registered in `Layout.PLOTS`, and access paths in `Layout.ROUTES`, when adding sites; this shared survey drives both terrain and vegetation exclusion. Whole plots are cleared, including houses, courtyards and entrances.

The wider road/plot buffers leave space for tall tips, wind and vehicle deformation. These are explicit reserved areas, not a claim of runtime collision-based detection of arbitrary unregistered buildings. Terrain, existing trees and settlements are preserved by the grass-only bake.

Raw instance-transform payload is approximately 116.5 MiB across the two layers (excluding geometry/resource/renderer overhead), up from 57.8 MiB. No full-game performance certification follows from the bake or focused review.

Final dense pass native Metal: all 1,271,970 centres passed the house/road/crop/water placement rules; 82,114 sampled roots matched rendered terrain within 0.000003 m and passed the slope limit. Tall subsets: 62,074 bank and 24,543 off-road tufts. Close and wide riverbank views inspected. Wind/cart recovery recheck passed (moving strength 0.66662, stationary residual 0.000672). Temporary outputs removed.
