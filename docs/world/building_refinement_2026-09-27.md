# Building refinement — 2026-09-27

This pass refines the existing Government House, Town Hall and District Police prototypes without changing their footprints, doors, stairs, plot positions or pickup IDs.

## Changes

- Government House: entrance reveal/head trim, portico column collars and roof coping; ground hall runner with binding, wall dado and framed panels, and ceiling beams. The panels sit on solid partitions away from room openings. New trim is non-colliding.
- Town Hall and District Police: front entrance surround, upper stringcourse and eave brackets; visitor benches and a side runner in both halls. The entrance and principal circulation route remain open.
- Civic interior validation now calls `KnifeStrike.strike()`, the current gameplay API, instead of a removed input handler.

## Evidence and limits

`tools/world/validate_government_house.gd` passed headless after the edit: 65 gate-to-hall capsule samples, 46 stair samples and eight door samples clear; 74 windows retained. Fresh Forward+/Metal exterior, facade, hall and upper-floor captures in `docs/world/captures/24_government_house_exterior.png` through `27_government_house_facade.png` were inspected. The hall runner and panels are visible; the distant estate silhouette is still simple and the upper rooms remain sparse. The interrupted full Metal validator run did not produce a final PASS marker, so the headless traversal result and inspected Metal pixels are separate evidence.

`tools/world/validate_civic_interiors.gd` passed headless after all civic edits, including stair/pickup/knife checks. An earlier full Forward+/Metal civic traversal passed before the final bench/runner edit. The later full world capture was interrupted without a final marker; the focused `tools/world/capture_building_refinement.gd` then captured the final Town Hall facade and hall in Forward+/Metal. Both `docs/world/captures/building_refinement_civic_exterior.png` and `building_refinement_civic_hall.png` were inspected: the entrance surround and stringcourse read from outside; inside, the benches and runner sit alongside the tables without closing the aisle. This focused stage has no terrain, so it is evidence of the building visuals, not world ground contact. The buildings remain procedural prototypes; the new detailing is a design inference rather than period or production art approval. No 8 GB device profile has been run.
