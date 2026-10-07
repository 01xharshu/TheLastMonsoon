# Building site placement — 2026-09-28

Town Hall, District Police, and Government House are instantiated at their surveyed Suryagarh plots. The approach routes meet their entrance areas in the current baked landscape.

| Building | Plot center (X, Z) | Plot grade | Approach endpoint (X, Z) | World review |
| --- | ---: | ---: | ---: | --- |
| Town Hall | (-320, -470) | 8 m | town_hall: (-320, -432) | capture (test output deleted) |
| District Police | (320, 120) | 10 m | east_bridge: (320, 150) | capture (test output deleted) |
| Government House | (-390, -110) | 8.5 m | government_house_avenue: (-390, -123) | capture (test output deleted) |

The fort trail grading had raised a corner of the Police plot by 1.266 m. `landscape_layout.gd` now fades that grading outside the Police plot; its sampled grade spread is 0 m. The affected landscape tiles were rebaked. In the fresh Metal views, Town Hall and Police entrance ramps visibly join their roads, and the Government House avenue aligns with its estate approach. No foundation gap or terrain intrusion is visible in these views.

## Verification

- `tools/world/validate_building_sites.gd`: headless and Forward+/Metal PASS; checks the actual settlement nodes against plot centers and all three route endpoints, then captures the images above.
- `tools/world/bake_landscape.gd`: Metal PASS (`/tmp/tlm_building_site_rebake.log`); 144 tiles, 2120 trees, 720 rocks.
- `tools/world/validate_civic_world.gd`: Metal PASS (`docs/world/civic_world_validation.json`); 419 route contact samples, maximum error 0.11333 m, Town Hall and Police foundations 0.45 m above their highest footprint grade, zero nature intrusions.
- `tools/world/validate_civic_interiors.gd`: headless PASS (`/tmp/tlm_building_civic_interiors.log`).
- `tools/world/validate_government_house.gd`: headless PASS (`/tmp/tlm_building_house_site.log`); gate, hall, stairs, and doors clear. Godot printed a resource-in-use shutdown diagnostic after the PASS.

## Live player follow-up — 2026-10-01

The earlier `SaveManager` and `ControllerFeedback` compile errors have cleared when launching normal scenes with the project's autoload services. The live Suryagarh player stair fixture now passes all eight Town Hall, Police, and Government House ascents/descents without jump input (`tools/world/validate_player_world_stairs.tscn`; `docs/world/player_world_stairs_validation.json`). A new focused fixture, `tools/world/validate_building_approaches.tscn`, drives the same controller from the Town Hall road endpoint, Police road endpoint, and just inside the Government House gate. All three runs reached or crossed their respective entrance/portico targets on foot, with their lateral alignment and ground support checked. Headless run exited 0 on 2026-10-01. The Government House run starts inside the gate and does not test opening it.

The capture fixture now loads the full Suryagarh scene and is launched through `tools/world/validate_building_sites.tscn`; the older isolated fixture lacked the newer household clock and charpai dependencies. Launching the full scene with `--script` also bypassed autoload registration, so use the normal scene command below. Fresh Forward+/Metal views were inspected: both civic ramps join the roads, and the House avenue meets the portico court without a visible foundation gap.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/world/validate_player_world_stairs.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/world/validate_building_approaches.tscn
/Applications/Godot.app/Contents/MacOS/Godot --rendering-driver metal --path . res://tools/world/validate_building_sites.tscn
```

Current Metal log: `/tmp/tlm_building_sites_20261001.log`; run exited 0, placement PASS, all three captures saved, no error lines. Refreshed image paths are the three captures linked above.

The full `tools/world/audit_civic_layout.gd` still reports the Old Fort's uneven plot and steep `fort_trail`/`fort_access` segments; its three building plots pass. These fixtures prove the tested direct approaches and stairs, while the Metal images cover their current appearance. They do not establish every approach angle or owner play approval.

## Government House gate follow-up — 2026-10-01

`tools/world/validate_government_gate.tscn` loads the actual world and sends the `interact` input event through the normal player input route. It verifies gate selection from outside, both leaves opening, the player walking from the external road through the gate to the portico and back, the clock's night closure, outside latch rejection, closed-leaf physical blocking, inside E release and exit, and dawn reopening. The headless run exited 0 with all checks passing (`/tmp/tlm_government_gate_20261001.log`). Setup places the player at each latch side and establishes an initially closed daytime gate; movement through the opening uses the actual player controller. It does not author hand-to-ring animation.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/world/validate_government_gate.tscn
/Applications/Godot.app/Contents/MacOS/Godot --rendering-driver metal --path . res://tools/world/validate_government_gate.tscn
```

Results: gate validation (test output deleted). Native Forward+/Metal also exited 0 with all checks passing and no error lines. Inspected views: open gate (historical test output unavailable), night latch (historical test output unavailable). The open leaves leave the central route clear; the closed leaves span the entrance. Night darkness limits inspection of fine timber details. Metal log: `/tmp/tlm_government_gate_metal_20261001.log`.

Next: normal-camera room walkthroughs and furniture/doorway clearance refinement across the three buildings. Gate behavior requires no production-code correction from this check; continuous character hand contact and owner play approval remain open.

Final whitespace check passes. The shared handoff size check currently fails at 64 lines / 6900 characters after concurrent task entries expanded; the gate entry is brief and complete, and the other tasks' entries were preserved. Concurrent fort additions include guards, cannons, and an armoury; they do not change the gate script, but a later room walkthrough should include them.
