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


## Senior chamber and office doors, 2026-11-14

The west office suite now has a stair-side partition, high ventilation and separate doorway openings on both floors. The senior chamber keeps the existing inquiry desk, drawer, three officials and their positions; a district chart, storage, document bundles and a visitor chair add to the established furnishings. Nearby bays receive wall boards and storage. Twelve paired half-height timber office and records-room doors are open by default and can be operated through the existing door interaction. Their leaves park against the wall to clear the inquiry guards' route.

The full-world station refinement, floor route and actual inquiry sequence passed with the enclosed office and parked doors. An isolated station/player check confirmed all three relocated ammunition pickups are visible and collectible; the full-world ammunition test reported PASS for traversal and save restoration but emitted null-material renderer errors on shutdown. A disposable pre-redesign station baseline also passed that test and emitted the same type of renderer errors. Native open/closed door and chamber views were inspected, with renderer diagnostics. A full manual station playthrough, the pre-existing renderer diagnosis and final visual approval remain open.

## Remaining gates

The station is still procedural candidate art. Detailed joinery, surface wear and owner play/camera review remain. Underground detention is fictional gameplay layout, not an approved reconstruction of a sourced colonial Indian station. No new downloaded assets: geometry/shader are original and existing project wood/plaster materials are reused. Merged static visuals and bounded non-shadowing lights support the 8 GB target; no physical 8 GB hardware memory/frame-time certification is claimed. World load still reports existing FortCook/FortSteward missing skeleton errors outside this station scope.


## Guarded access and stair movement, 2026-11-05

The upstairs corridor has an additional sentry using the retained complete MPFB burkundaz model. Reception and the ground-floor report desk remain public. Upper offices and their stair approach, the armoury and lower detention rooms are restricted. An actual station guard must see Arjun in a restricted area before the existing crime owner records the entry. Repeated checks and restored evidence for the same active case retain one report. The existing rebellion uniform owner grants access only while its disguise is actually worn. Story and custody sequences keep their own authority.

Officers moving between the ground floor, upper offices and lower detention level use the existing queued navigation budget, local floor searches and the physical staircase. Path queries check the stair run at quarter-metre intervals and retain spaced movement goals. The mover samples nearby physical floor support inside the station, clears the landing lip before descending and keeps full capsule collision. Matching horizontal coordinates on separate floors no longer count as arrival or permit a melee attack through the floor. The ground-floor arrest coordinator selects an officer from the same floor. Existing cinematic external custody remains the handoff for encounter arrests.

The reusable actual-world check is `python3 tools/world/run_tutorial_guard_check.py --checks validate_station_floor_navigation`. It walks the real MPFB officer upstairs and back, checks floor-height continuity and stair placement, then exercises a wall-occluded entry, a visible report, repeated and restored evidence, an unworn disguise flag and the actual fitted uniform owner. Add `--native --review` for temporary stair views and signal `station_floor_done` after inspection. The direct upper-to-cellar and cellar-to-upper routes are exercised with `TLM_STATION_CROSS_FLOOR=1`. A full manual restricted-room playthrough and stair foot/clothing review remain open.
