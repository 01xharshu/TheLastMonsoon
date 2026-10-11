# City placement and connected homes

Updated 2026-10-11. The western city follows the agreed order: village → cultivated countryside → rural approach → city market → residential lanes → college and adjoining café. Eastern administration, Civil Lines and the military hospital remain connected districts across the river. Government House and its British household remain on the western civic avenue; the landowner stays beside agricultural land.

## Actual placement

| Place | World X/Z | Relationship |
| --- | --- | --- |
| Village centre | −332 / 232 | Homes, village market and cultivated estate edge |
| City gateway | −250 / −295 | Rural approach meets the city market street |
| Trading market | −340 / −310 | Seven stalls beside the merchant's counting house |
| City homes | −280…−402 / −350, −382 and −430 | 26 attached houses; 14 have upper floors and internal stairs |
| Merchant home | −420 / −405 | Private home/service court connected to counting house at −366 / −328 |
| Merchant receiving store | −397 / −429 | Covered rear service bay keeps freight clear of the family entrance and coach court |
| Civilian hospital | −205 / −388 | Treatment and four beds; front approach connects directly to the main road |
| College reading room | −375 / −520 | Existing story destination retained as the same node at its new location |
| College lecture hall | −418 / −520 | Separate benches/lectern connected by a pedestrian arcade |
| College café | −375 / −484 | 36 m from the reading room, reached without walking through tables |
| Military hospital | 457 / 515 | Existing cantonment institution, separate from civilian care |

The rural approach follows the existing curved road. The village centre and college are approximately 754 m apart directly; actual travel follows the village exit and surveyed road. The agricultural buffer is retained, rather than filling the entire distance with buildings. New city routes and the graded urban terrace are shared by terrain, nature clearance, map drawing and pedestrian routing.

## Density and escape paths

Each city home has front and rear **paired physical door leaves**. Twenty-six front-to-rear corridors exit onto another lane. Thirteen neighbouring pairs also have opposing side doors connected across a two-metre covered passage. The central room openings remain clear; furniture sits beside them. Public roads connect both ends of the alley grid, so a rear exit does not strand the player in a sealed court.

Doors use the existing swept hinge/latch interaction. They can close automatically and be manually locked; opening and inside egress use the shared door rules. Physical openings and collision are retained at distance. Upper floors have stair handrails, guarded stairwell edges, sleeping mats and storage. Continuous timber floor rims close the exterior band around the staircase opening. Closed triangular gables and raised roof eaves seal the wall-to-roof joins without covering the ridge with a box. Door frames have stable names for saving; earlier automatic jamb paths migrate on loading. The northern row names the correct college front/rear streets in its exit metadata. The houses are functional construction candidates; final architectural detailing and interior population remain open.

## People and services

The current eight college/café MPFB residents now have student, lecturer and printer roles. Two café readers are marked as educated rebels among ordinary patrons, with discreet authored discussion. This establishes a social meeting place; the main rebellion mission implementation in `story/rebellion_story.gd` is reviewed separately from these house checks.

Three additional city walking routes provide 22 persistent pedestrian identities, taking the authored city walker total from 72 to 94. They reuse the existing gradual spawning, saved population, shared simulation tiers and swept movement. The added civilian attendant also reuses a complete MPFB body and opaque foundation clothing.

Civilian treatment shares the military ward's charge, cancellation, stock and healing rules but has an independent persistent ledger. Its service is available during the existing 06:00–20:00 service hours. Mid-service saves resume idle without charging twice. Prices are fictional gameplay values.

## Verification and review

- Focused physical checks passed 26 through-house corridors, 13 neighbour passages and 14 staircases, civilian treatment/daily limits, stable door save/rebuild and legacy jamb-path migration. Receiving-worker saves preserve carried cargo when migrating to the rear bay; repeated loading does not shift the actor again.
- Regional terrain bake updated nine western tiles, cleared 6,090 nature instances from the footprint/roads and preserved other saved tiles. The field-map texture was rebuilt.
- Placed household role selection and real temporary save/load passed after merchant relocation.
- Full household-cycle verification passed all four residents through 16 activity states, with all three household coaches returning and zero blocked household walking/coach routes. Thirteen independent AnimationTrees were present.
- Isolated native house views, including the revised gables/eaves, were inspected; the exposed inter-storey band was repaired with timber perimeter rims. Whole-world native review timed out; final architecture, player foot contact, interior occupation and actual world frame times remain open. City traffic is being verified separately by its owner.
- A shared population discovery queue exposed a freed-node assignment error during integration. It now checks a Variant before casting to Node; the focused regression drains that stale entry.

Reusable checks: `tools/world/validate_urban_west.gd`, `tools/world/review_urban_west.gd` via `python3 tools/world/run_urban_review.py`, `tools/world/validate_wealthy_households.gd` and `tools/world/validate_city_route_population.gd`. Rebuild inputs: `tools/world/bake_urban_west_region.gd` and `tools/world/bake_field_map.gd`. Native captures use OS temporary folders and are deleted after inspection; no test reports or recordings are retained.

Try in game: enter the city at −250/−295, walk the market, enter a house from the front street, cross to its rear lane or paired neighbour, then follow the college road to the café. Use the civilian hospital's south entrance. Meet the merchant at home or the nearby counting house and observe his complete coach return.

House integration now classifies the actual college/café venue residents after their spawn queue drains, rather than assuming sixteen occupants. Road residents do not count toward that readiness check.
