# Bhairavpur streets and resident journeys
Updated: 2026-10-01. Status: IN_PROGRESS; integrated route behavior PASS, final visual quality open.

## Implemented
`village_street_life.gd` is attached by the settlement builder after the existing village. Seven shared layout road chains and two foot approaches receive terrain-following earth strips, dry-mud texture/normal, paired wheel wear and irregular faded shoulders. Road strips add no new collision: the actual landscape remains the ground. Widths and wear are fictional design choices, not authenticated local measurements. Existing homes, market stalls and trees are preserved.

Two candidate residents, ClothMarketVisitor and GrainStoreBuyer, use independent household actor rigs and AnimationTrees. They travel at 0.85 m/s between a home approach and the cloth market/grain store, pause at destinations and return home after 18:00; departures reopen at 06:00. Swept capsule checks halt motion when the corridor is obstructed. They stop on death. They use private street variants derived from merchant/landowner bodies, so unique identities and a larger population remain required. Waiting does not yet reroute around a moving obstruction.

The first cloth-market route crossed Arjun's courtyard wall. The corrected route reaches the western lane through the southern dogleg. Private street GLBs now have thigh-following lower wraps, a continuous waist fold, trimmed shirt hem and shaped leather shoes with flat soles. The original shared household GLBs stay untouched. Native motion exposed missing donor body geometry beneath the old garment; the moving hems now maintain coverage. Clothing form and natural cloth/foot contact still need owner review. Sources: `tools/characters/build_street_residents.py`, `WorkingAssets/NPCs/street_residents/`.

## Verification and pixels
`tools/world/validate_village_streets.gd`, final Forward+/Metal log `/tmp/tlm_village_streets_final.log`, report `village_streets_validation.json`: PASS.
- Nine strips; 170 actual terrain samples; maximum ground offset 18.0001 mm.
- Complete swept-shape route sampling: 353 cloth-market and 292 grain-store samples, all 645 clear.
- Initial displacement and walk state, repeated market/home visits, and night return PASS. Accelerated scripted cycles verify route logic, not continuous normal-speed play.
- Fresh `captures/village_earth_market.png` and `captures/village_street_walker.png` inspected after shoe fit. Earth aisle connects the existing market frontage. House surfaces, street clutter, shop activity, pedestrian variety, footwear shape and garment motion need refinement.

Normal-speed staged walking: `tools/world/capture_street_walk.tscn`, `captures/street_walk_motion_20261001.mp4`, 143 frames at 30 fps (4.767 s), `/tmp/tlm_street_walk_video_fixed.log`. Frames at 1 s and 3 s inspected: positions and gait change. Footwear remains rounded; garment movement exposes small dark leg/cloth intersections and foot-contact realism is not accepted. It uses the live journey/actor implementation on an isolated flat lane, not the complete village. Two recorder attempts advanced timing unevenly and were rejected; final timing advances in the physics step, with explicit drawing in process.

## Refined motion and household cattle continuation
Final route regression after private resident refit and cattle placement: `/tmp/tlm_street_routes_refit_final.log`, Forward+/Metal, all previous 9-lane/645-corridor/cycle/night checks PASS. Fresh market and walker pixels regenerated and inspected.

`captures/street_walk_refined_20261001.mp4`: 90 individually rendered steps at 1/30 s, 3.000 seconds, 1280x804 (one padding row for encoder). Fixture `tools/world/capture_street_walk_frames.tscn`; `/tmp/tlm_street_frames_final.log`. Frames at 0/2 seconds inspected: displacement and leg phases change, former knee gaps covered, shaped shoes visible. This is staged live-journey motion rather than normal play in the full village. MovieMaker attempts had uneven simulation/render counts and were superseded by individually rendered fixed-step frames. Fine drape and continuous sole/sliding contact remain open.

The refined original cow is now integrated as a **functional visual candidate** in a shelter associated with north-lane `BhairavpurHouse27`. Manger/real pouch-to-trough care, ownership, supports/clearance and save-file restoration PASS. Appearance, caretaker and natural feeding/walking/grazing remain open. Details: [household cattle](household_cattle_2026-10-01.md).

## Remaining owner scope
Continue road drains, edges, wear and household details; distinct walkers/shop activity and natural foot/cloth motion; credible household cattle and ownership loop. River expansion must remain consistent with the active port/channel terrain work. Cart damage and telescope evidence are in [the main scope ledger](living_roads_and_cart_combat.md). Full-world normal play, owner appearance acceptance and 8 GB frame-time checks remain open.
