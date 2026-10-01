# Bhairavpur streets and resident journeys
Updated: 2026-10-01. Status: IN_PROGRESS; integrated route behavior PASS, final visual quality open.

## Implemented
`village_street_life.gd` is attached by the settlement builder after the existing village. Seven shared layout road chains and two foot approaches receive terrain-following earth strips, dry-mud texture/normal, paired wheel wear and irregular faded shoulders. Road strips add no new collision: the actual landscape remains the ground. Widths and wear are fictional design choices, not authenticated local measurements. Existing homes, market stalls and trees are preserved.

Two candidate residents, ClothMarketVisitor and GrainStoreBuyer, use independent household actor rigs and AnimationTrees. They travel at 0.85 m/s between a home approach and the cloth market/grain store, pause at destinations and return home after 18:00; departures reopen at 06:00. Swept capsule checks halt motion when the corridor is obstructed. They stop on death. They currently reuse merchant/landowner bodies, so unique identities and a larger population remain required. Waiting does not yet reroute around a moving obstruction.

The first cloth-market route crossed Arjun's courtyard wall. The corrected route reaches the western lane through the southern dogleg. A private mesh fit shortens oversized shoes on these new instances only; shared household GLBs remain untouched. Fresh native pixels still show simplified footwear and cloth, so neither clothing nor historical appearance is approved.

## Verification and pixels
`tools/world/validate_village_streets.gd`, final Forward+/Metal log `/tmp/tlm_village_streets_final.log`, report `village_streets_validation.json`: PASS.
- Nine strips; 170 actual terrain samples; maximum ground offset 18.0001 mm.
- Complete swept-shape route sampling: 353 cloth-market and 292 grain-store samples, all 645 clear.
- Initial displacement and walk state, repeated market/home visits, and night return PASS. Accelerated scripted cycles verify route logic, not continuous normal-speed play.
- Fresh `captures/village_earth_market.png` and `captures/village_street_walker.png` inspected after shoe fit. Earth aisle connects the existing market frontage. House surfaces, street clutter, shop activity, pedestrian variety, footwear shape and garment motion need refinement.

Normal-speed staged walking: `tools/world/capture_street_walk.tscn`, `captures/street_walk_motion_20261001.mp4`, 143 frames at 30 fps (4.767 s), `/tmp/tlm_street_walk_video_fixed.log`. Frames at 1 s and 3 s inspected: positions and gait change. Footwear remains rounded; garment movement exposes small dark leg/cloth intersections and foot-contact realism is not accepted. It uses the live journey/actor implementation on an isolated flat lane, not the complete village. Two recorder attempts advanced timing unevenly and were rejected; final timing advances in the physics step, with explicit drawing in process.

## Cow source candidate
`tools/animals/build_household_cow.py` creates original geometry and a 13-bone rig, with editable `WorkingAssets/Animals/household_cow/household_cow.blend`, manifest and `assets/animals/cow/household_cow.glb`. No third-party geometry or imagery is included. 21,611 vertices; idle and head_lower clips. The latter is only a head dip, not a grazing-contact animation.

Native import and clips PASS (`/tmp/tlm_cow_review_refine.log`). First review found detached lower legs/hooves and an exaggerated female hump. Source corrected and rebuilt; fresh side pixels now show connected hooves, but barrel/head/dewlap/leg shaping and coat detail remain visibly simplified. **Candidate is not placed in the world.** Next sculpt a credible female silhouette and foot joints, review three views and motion, then build the household-owned shelter/feed/water space and interactions. Calf, walking, grazing contact, tethering and ownership behavior are not implemented.

[FAO zebu anatomy](https://www.fao.org/4/t1265e/t1270e03.htm) informed broad morphology only; modern anatomy does not establish an exact 1857 regional breed. [British Library's 1858 Lucknow bazaar catalogue](https://searcharchives.bl.uk/catalog/040-003096659) provides urban market context, not direct evidence of this fictional rural settlement or its lane dimensions.

## Remaining owner scope
Continue road drains, edges, wear and household details; distinct walkers/shop activity and natural foot/cloth motion; credible household cattle and ownership loop. River expansion must remain consistent with the active port/channel terrain work. Cart damage and telescope evidence are in [the main scope ledger](living_roads_and_cart_combat.md). Full-world normal play, owner appearance acceptance and 8 GB frame-time checks remain open.
