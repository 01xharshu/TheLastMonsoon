# Building site placement — 2026-09-28

Town Hall, District Police, and Government House are instantiated at their surveyed Suryagarh plots. The approach routes meet their entrance areas in the current baked landscape.

| Building | Plot center (X, Z) | Plot grade | Approach endpoint (X, Z) | World review |
| --- | ---: | ---: | ---: | --- |
| Town Hall | (-320, -470) | 8 m | town_hall: (-320, -432) | [capture](captures/building_site_town_hall.png) |
| District Police | (320, 120) | 10 m | east_bridge: (320, 150) | [capture](captures/building_site_district_police.png) |
| Government House | (-390, -110) | 8.5 m | government_house_avenue: (-390, -123) | [capture](captures/building_site_government_house.png) |

The fort trail grading had raised a corner of the Police plot by 1.266 m. `landscape_layout.gd` now fades that grading outside the Police plot; its sampled grade spread is 0 m. The affected landscape tiles were rebaked. In the fresh Metal views, Town Hall and Police entrance ramps visibly join their roads, and the Government House avenue aligns with its estate approach. No foundation gap or terrain intrusion is visible in these views.

## Verification

- `tools/world/validate_building_sites.gd`: headless and Forward+/Metal PASS; checks the actual settlement nodes against plot centers and all three route endpoints, then captures the images above.
- `tools/world/bake_landscape.gd`: Metal PASS (`/tmp/tlm_building_site_rebake.log`); 144 tiles, 2120 trees, 720 rocks.
- `tools/world/validate_civic_world.gd`: Metal PASS (`docs/world/civic_world_validation.json`); 419 route contact samples, maximum error 0.11333 m, Town Hall and Police foundations 0.45 m above their highest footprint grade, zero nature intrusions.
- `tools/world/validate_civic_interiors.gd`: headless PASS (`/tmp/tlm_building_civic_interiors.log`).
- `tools/world/validate_government_house.gd`: headless PASS (`/tmp/tlm_building_house_site.log`); gate, hall, stairs, and doors clear. Godot printed a resource-in-use shutdown diagnostic after the PASS.

The full `tools/world/audit_civic_layout.gd` still reports the Old Fort's intentionally uneven plot and steep `fort_trail`/`fort_access` segments; its three building plots pass. A player stair test was blocked by `SaveManager` and `ControllerFeedback` compile errors in concurrent player/UI work (`/tmp/tlm_building_player_stairs.log`). The fresh views and focused collision samples do not establish a complete manual player traversal of all three approaches.
