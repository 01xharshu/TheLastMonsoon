# Port-to-village uplands

12 October 2026. Scope: the longer port-to-village journey and terrain for a future police chase. The chase mission itself is not implemented here.

The production saved landscape contains a 1,676 m winding hill route from the port approach at (-185,500) to Bhairavpur's west/north-lane junction at (-374,312). Paid-coach travel from the actual port stop follows roughly 1,928 m. The first 460 m of the hill route is almost level, rising from 5 m to 9 m; the sustained climb begins farther along the approach. It then winds west, climbs through separate passes to a 42 m road crest, returns around the rock mass and descends toward the village. Maximum authored road grade is 0.1703. This replaces the shorter route and immediate hill approach rejected by the user.

`landscape_layout.gd` remains the shared terrain/road authority. `port_village_uplands.gd` stores the editable road coordinates, elevations, connected hill mass, road-cut shoulders and dry lower-road cutting. The surrounding rock mass binds the winding passes together. Steep sides and connected cutting branches prevent the intended direct walking bypass toward the village. There are no authored shortcut routes. This is not proof against every climbing/jumping/vehicle exploit.

The overpass is a straight 50.2 m timber span, 8 m wide, at approximately 1.4% grade. It has one uninterrupted collision deck, transverse planks, side trusses, longitudinal bearers and four support bents. The two inner supports flank the lower road rather than standing in its passage. Each support uses the actual terrain height at its foot. Both deck ends match the continuing road's surveyed grade. The previous bent deck and isolated banks were rejected and replaced; they are not approved assets. The bank is now part of the broad, continuous road embankment, with a dry packed-earth road passing beneath. No river/water surface is created beneath this crossing.

Bridge timber is merged into one renderable mesh offline. Collision stays physical, deck support remains in the existing terrain-support registry, and the bridge adds no autonomous processing callback. Terrain/nature retain the existing visibility and LOD systems. Lower service-road paths are excluded from the planar coach graph so an overlap in the map cannot connect the upper and lower elevations.

The incremental bake updates 40 affected terrain tiles, saved terrain collision, rooted vegetation, the current road mask and the bridge. Road paint is rebuilt from current authoritative routes inside the affected region so abandoned shorter routes do not remain painted as apparent shortcuts. Ship/quay, village buildings and other site construction remain in their existing positions. The world remains 1728 × 1728 m; expansion here means a much longer traversable journey within the port/village corridor.

Rebuild in order:

1. `Godot --headless --path . --script res://tools/world/bake_port_village_uplands.gd`
2. `Godot --headless --path . --script res://tools/world/bake_field_map.gd`

Reusable checks:

- `tools/world/validate_port_village_uplands.gd`: route length, gradual approach, authored grades, village connection, lower-road continuity, straight bridge and matching approach grades.
- `tools/world/review_port_village_uplands.gd`: saved collision, walking capsule clearance and actual coach path; native landscape-only views are optional.
- `tools/world/validate_port_bridge_walk.gd`: actual production Arjun controller walks the upper deck in both directions and the lower road beneath it.
- `tools/world/review_port_village_world.gd`: production-world loading and native views of the flat approach, winding pass, bridge, underpass and overview.
- `tools/world/review_dev_story.gd`: production opening, horse/cart/on-foot station arrival, recovery and save regression.

All output and saves must use OS temporary directories via `TLM_TEST_OUTPUT_DIR` or `TLM_STORY_TEST_DIR` and be deleted in the invoking wrapper's finally cleanup. No generated test evidence is retained.

Current revised saved-terrain result: 1,125 capsule clearance samples PASS; maximum sampled grade 0.2433 (about 14 degrees); actual coach path 208 points and 1,928 m, with the long approach retained. Final production-player walking, main-world regression and native review are in progress. These checks do not certify whole-world FPS, all horse/cart turning and contact, final landscape art or future chase pacing. The long rock cuts and terrain transitions require normal-play review; numerical clearance does not grant visual approval.
