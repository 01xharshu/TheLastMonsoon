# Household batch 02 — water pot, pouch, oil lamp

2026-09-30 IST. **MODEL CANDIDATES BUILT / HERO ANIMATION DEFERRED**. Owner direction: complete asset batches first; do character animations in the final pass. Required actions remain in [the checklist](asset_first_checklist.md).

Original deterministic meshes/materials; no new third-party downloads or historical-authenticity approval. Builder: `tools/assets/build_water_light_batch.gd`. Review fixture: `tools/assets/review_water_light_batch.gd`.

| Asset | Result | Integration / remaining work |
| --- | --- | --- |
| Earthen water pot | Hollow 0.8 m vessel, rounded lip, inner wall, visible stored-water surface, terracotta grain/turning bands. Mouth/water/grip markers. 3,200 triangles. | `objects/water_pot.tscn` replaces primitive, preserving script/scene UID and old centre origin (base -0.4 m). Collider resized. Existing village well uses its own geometry and water-pot script; it remains a well. |
| Leather water pouch | 0.26 m wide, 0.335 m body with separate wooden stopper, stitched edge binding and carry loop. Mouth/grip/belt markers. 3,680 triangles. | `objects/water_bag.tscn` and player's `PouchModel` share `objects/household/water_pouch_visual.tscn`. Concurrent `water_bag_visual.gd` carries/deforms this model for empty/half/full states; preserve its fitted socket and sash keeper. Hand-use animations deferred. |
| Brass oil lamp | Open reservoir/oil surface, tapered wick trough, wick and emissive flame. Wick/grip markers. 2,350 triangles. | `objects/oil_lamp.tscn` retains `LampBody` and `LampLight`; switching synchronizes nested flame visibility. Village night-life hides the whole `LampBody` and provides its own replacement/flame, so no duplicate new flame appears there. Replacing that village dressing is a later coordinated placement task. |

All baked visuals are reusable `objects/household/*_visual.tscn` scenes and mesh resources in `assets/props/household/`. Contact markers are reference points, not validated hand poses. Prototype gameplay transactions remain immediate, pending the final animation pass.

## Verification and evidence

- `water_light_validation_headless.json` and `water_light_validation_metal.json`: actual physics ray contacts for all three assets, no-pouch refusal, one-pouch pickup/removal, full/partial water filling without overfill, lamp light/flame switching, and player scene/shared visual presence PASS. These direct interactions do not prove the full E/hold route.
- Existing `tools/characters/validate_water_bag_waist.gd`: clean final headless PASS for pinned sash, turn/sway, empty/half/full state and removal. Initial attempt encountered a concurrent `arjun_clothing.gd` inference error; that file changed independently before the repair attempt. Clean rerun supersedes the error-containing PASS marker.
- Native Forward+/Metal views: `water_light_overview.png`, `water_light_water_pot.png`, `water_light_water_pot_mouth.png`, `water_light_water_pouch.png`, `water_light_oil_lamp.png`. Initial pot rim seam and rectangular spout were repaired; final captures inspected: closed rim, visible pot interior/water, pouch seam/stopper/loop, tapered lamp trough and flame. Studio appearance remains a candidate, not owner approval.
- Final hero appearance, hand/pouch contact, source use, regional period form, full-world placement/route review and owner approval remain open. Standalone materials and silhouettes remain candidates.

## Final animation pass requirements

- Pot: retrieve/unstop pouch → position near pot opening → transfer water with a credible pouring vessel/source method → stop/close → return to belt. Handle standing/table/floor heights separately.
- Pouch: pickup and belt attachment; retrieve/stopper removal; fill and drink at the mouth; close and reattach; one visible pouch during transfer. Preserve inventory-driven fullness and sash pin.
- Lamp: approach wick, light/extinguish, recover; specify ignition tool before building the lighting animation.

Next asset batch: review existing crate/bucket/brass pot/basket/stool/bench/barrel against their original source and support evidence; then small paper/clue/supply props. Defer all new hero-action animation work to the final pass.
