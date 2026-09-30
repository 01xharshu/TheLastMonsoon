# Household batch 01 — roti, grain sack, woven mat

2026-09-30 IST. Status: **ASSET CANDIDATES / INTERACTION ANIMATION OPEN**.

Original deterministic geometry and procedural materials, with no new third-party downloads. Rebuild: `tools/assets/build_household_batch.gd`. Standalone checks/captures: `tools/assets/review_household_batch.gd`.

| Asset | Scene | Changes / limits |
| --- | --- | --- |
| Roti | `objects/roti.tscn` | Replaces cylinder with irregular ~26 cm bread, raised centre and toasted surface; preserves pickup script and scene UID; collision sized to bread. Existing scene users receive updated visual. Procedural toast is a candidate, not final food realism. |
| Tied grain sack | `objects/household/grain_sack.tscn` | Gathered cloth silhouette, woven surface, neck cord/tails; ~0.57 m tall, floor-origin convex collision, `solid_period_prop` group. Static dressing; no carrying or grain inventory implied. |
| Woven reed mat | `objects/household/woven_mat.tscn` | ~0.9 × 1.6 m, separate reeds with over/under bindings and bound long edges. Thin support collision; five material batches. No sitting/sleeping behavior implied. |

Generated meshes are under `assets/props/household/`. Sack/mat have not been substituted into concurrent village scripts. Existing market sacks and gathering mats remain until world integration.

## Evidence

- `household_validation_headless.json`: all three collision rays hit the correct asset; roti interaction adds exactly one inventory item and removes the world pickup. This tests the transaction directly, not the player E/hold route or animation.
- `household_validation_metal.json`: same standalone fixture in Forward+/Metal PASS.
- `household_overview.png`, `household_roti.png`, `household_grain_sack.png`, `household_woven_mat.png`: native render captures. Fresh sack capture confirms the repaired shell is visible and seated on the studio floor. Mat binding winding repaired; final native captures inspected with visible over/under threads. Thin binding detail still aliases at this distance. Roti toast pattern and regular sack folds remain visibly procedural and need further art refinement. Owner approval remains open.
- Mat reduced from 73,344 to 3,248 triangles; sack 4,784; roti 3,200. Mat geometry reduced by replacing hundreds of cylindrical binding pieces with woven ribbons; cords/reeds baked by material to avoid runtime construction and excessive node count.

## Required hero work

Roti: approach at ground/table height → free hands/stow weapon → reach/grip → lift → open satchel → insert → close/recover. Separate consumption: retrieve → hold/tear or bite → chew → handle remainder → recover. Existing generic reach is not this sequence.

Sack/mat: no animation required while decorative. If lifting sack or sitting/resting on mat becomes supported, add weight-aware lift/carry/place or sit/rest/get-up respectively before advertising the interaction.

Next: integrate sack/mat into agreed locations with floor and route checks; roti held-prop/satchel animation is deferred to the final pass by owner direction. Main-world player feel, historical form, owner art approval and target-device performance remain open.
