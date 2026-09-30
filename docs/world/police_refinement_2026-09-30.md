# Station masonry, ventilation, lighting and furnishings

Implemented in the actual Suryagarh DistrictPolice building on 2026-09-30.

## Changes

- Original world-scaled staggered masonry shader with restrained mortar, stone variation, rough joints and damp lower courses. Projecting plinth and alternating corner quoins add silhouette detail; plaster remains on the main walls.
- Side walls have actual high openings, timber louvres and retained structural piers. Office doorway transoms and high partition openings provide cross-room paths. This is geometric ventilation, not airflow simulation.
- Eight suspended oil-lantern fixtures use warm local light, ranges of 5.5–7.5 m, distance fade from 22–30 m and no added shadow maps. Ceiling suspension replaces unsupported floating brackets. The broad hall fill is reduced.
- Reception has its own desk, papers, inkwell, writing reed, chair and waiting benches. West offices have writing chairs and tied register shelves with cabinet backs. Upper rooms have a noticeboard, coat pegs, storage chest and folded bedding. Existing armoury, holding cells, cellar and upper sidearm support remain.
- Generic duplicated meeting tables are removed from the police station except the upper weapon support. Main aisle, stair aperture and supplies remain accessible.

## Evidence

- `tools/world/validate_police_refinement.gd`: PASS, 26 clear external/office vent rays, eight bounded lights, five chairs and duty storage. Report: `police_refinement_validation.json`.
- `tools/world/validate_civic_interiors.gd`: CIVIC INTERIORS PASS, actual player entry/upper stair and supply route.
- `tools/world/validate_police_ammunition.gd`: POLICE AMMUNITION PASS, actual cellar descent/ascent, office doorway, ammunition collection/reserves and save restoration.
- Forward+/Metal fresh 1280×720 captures from actual world: `captures/police_refinement_masonry_vents.png`, `police_refinement_reception.png`, `police_refinement_records.png`, `police_refinement_duty_room.png`, `police_refinement_cellar.png`, `police_refinement_night_reception.png`. Capture tool advances the actual game clock for the night view. Views inspected for supports, furnishing placement and lighting; screenshots are not continuous player approval.

## Remaining gates

The station is still procedural candidate art. Detailed joinery, surface wear and owner play/camera review remain. Underground detention is fictional gameplay layout, not an approved reconstruction of a sourced colonial Indian station. No new downloaded assets: geometry/shader are original and existing project wood/plaster materials are reused. Merged static visuals and bounded non-shadowing lights support the 8 GB target; no physical 8 GB hardware memory/frame-time certification is claimed. World load still reports existing FortCook/FortSteward missing skeleton errors outside this station scope.
