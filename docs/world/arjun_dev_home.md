# Arjun and Dev’s home

Updated 2026-09-30 IST. First playable home prototype; art and normal player traversal approval remain open.

Dev raised Arjun after their parents died early. Dev serves as a sepoy; the household is modest and middle class. The home reuses surveyed `BhairavpurHouse0` at world X -343, Z 214, grade 7.2, facing the south lane. It does not introduce a new terrain plot or change the village road network.

The existing tiled roof, timber veranda, windows and plaster exterior surround two connected rooms. Arjun’s charpai occupies the left sleeping alcove. The right room has Dev’s bedding mat and rolled quilt, a timber storage chest with iron fittings, brick cooking hearth, shelf, brass pot and wicker basket. A peg rail and blue cloth add household detail. The enclosed earth courtyard has a wide gate and a 2.4 m approach to the existing south lane. Generic furniture is skipped for this house to prevent duplicate furnishings.

Implementation: `world/suryagarh/settlements/arjun_house.gd`, integrated by `bhairavpur_village.gd`; the generic interior exception is in `bhairavpur_house_detail.gd`. The existing root `Charpai` node is retained for interaction/save references. Its home-local origin is (-2.35, 0.24, -1.4), resting on the house plinth.

## Evidence and limits

Run `/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/world/validate_arjun_house.gd`; use `TLM_HOUSE_VIEW=interior` or `kitchen` for other views. Default captures exterior.

- 112 sampled capsule/support positions from lane through doorway to the bed passed. This checks geometric clearance, not actual controller movement across thresholds.
- Full-world charpai interaction completed, released the player and advanced the clock by 480 minutes. Latest interior run: `/tmp/tlm_arjun_house_interior.log`.
- Metal captures: `captures/arjun_house_exterior.png`, `captures/arjun_house_interior.png`, `captures/arjun_house_kitchen.png`. Exterior, sleeping-room and kitchen images inspected; kitchen run `/tmp/tlm_arjun_house_kitchen.log` passed; duplicate generic timber remnants removed and sleeping room recaptured.
- Furniture uses existing shared materials and period props. Forms remain prototype quality; exact historical fidelity, fine wear/joinery, kitchen styling and continuous sleep/body contact are not approved by these checks.

## Next actions

Walk the normal player from the south lane through the gate and doorway, approach the charpai, sleep and leave; review third-person camera inside both rooms. Then refine household surfaces and cloth detail without blocking circulation.

After this home milestone, survey city/village/ruins/forest/river connections together. Establish protected roads, building footprints and walking/cart corridors before adding density. Add trees and planted margins outside those clearances, then expand river edges and connect cart/NPC routes. Keep each stage independently testable; do not scatter unrelated props to fill empty space.

## Actual controller route — 2026-10-01

`tools/world/validate_arjun_home_traversal.gd` drives the normal controller with `move_forward` and camera yaw, starting once on the south lane. No intermediate waypoint teleport occurs. Headless entrance, bed approach, sleep release and exit to the lane PASS: `/tmp/tlm_home_traversal.log`. Eight waypoints reached; final home-local position approximately (0, 0.90, 24.35). The report is `arjun_home_traversal.json`. This validates controller traversal with scripted steering, not human input feel or animation approval. Physical hinged doors and the opening cinematic added since the first house pass are preserved; cinematic work remains tracked in `opening_sequence.md`.

Metal run: `/tmp/tlm_home_traversal_metal.log`; gameplay camera capture `captures/arjun_home_player_camera.png`. Metal controller route PASS; fresh gameplay-camera pixels inspected. The camera remains inside the room at the bed approach and shows Arjun, cot and partition; continuous camera rotation/sweep and human input feel remain open. The shared handoff currently exceeds its character gate due to active concurrent entries; no other task sections were removed.

## Home refinement — 2026-10-01

Local `home_surface.gdshader` adds restrained plaster mottling, timber grain and woven cloth without modifying shared village materials. The partition gets a low worn skirting; chest board seams, forged nails and shelf brackets clarify construction. Dev’s quilt is now a rounded roll with ties and the mat has bound edges. New detail is non-colliding and outside the route; the existing chest/hearth colliders are preserved. Fresh kitchen capture and route/sleep regression: `/tmp/tlm_home_refinement.log`. Metal kitchen pixels inspected; 112 clearance samples and eight-hour sleep/release PASS. `git diff --check` PASS. Final surface/contact acceptance remains open. Next exterior wear, garden/courtyard detailing and continuous player-camera sweep.

## Period presentation — 2026-10-01

Period target is 1856–1859 Bengal. Tania Sengupta’s architectural study discusses nineteenth-century provincial domestic forms and the courtyard/veranda relationship: https://discovery.ucl.ac.uk/1360172/1/10.1080-13602365.2013.853683.pdf . This supports the spatial direction; it does not authenticate this fictional sepoy household’s precise materials or plan.

Removed the generic grey grid material from the plinth/thresholds, applying an earthy finish without moving floor or collision heights. Walls and courtyard enclosure receive muted lime/earth colours. The regular brick-pattern hearth now uses clay finish and a localized soot patch. Timber shutters, roof tiles, low bedding, chest and brass/wicker utensils remain; no modern plumbing, electrical fittings or polished tile decoration added. Fresh Metal kitchen and access/sleep result: `/tmp/tlm_home_period.log`. Initial render revealed nested material assignment missed the plinth; corrected wrapper-child traversal. Soot edges cut to an irregular plume. Corrected Metal pixels inspected: grey grid removed, earthy floor visible. 112 route/sleep checks PASS; pre-existing FortCook/FortSteward skeleton errors remain unrelated. Next refine exterior roof/veranda/weathering; exact historical fidelity stays open.

## Floating detail repairs — 2026-10-01

The night-life builder placed Arjun’s lamp shelf at X 1.72, in open space. Home0 now uses X 0.37 against the partition, with brackets spanning X 0.08–0.40; other houses are unchanged. Kitchen brackets now extend to the wall’s inner face instead of ending short. Quilt ties lowered to the roll. Veranda beam/knee braces/post feet and eaves/gable rafters added to clarify load-bearing connections, outside the doorway aisle. Files: `arjun_house.gd`, `village_night_life.gd`. Fresh kitchen/contact/access/sleep: `/tmp/tlm_house_support.log`; exterior: `/tmp/tlm_house_support_exterior.log`. Kitchen Metal pixels inspected: lamp shelf/brackets meet partition, kitchen brackets meet wall, ties lie on quilt. Kitchen 112 route samples and sleep/time release PASS. Exterior recapture inspected after adding a 0.5-second settle before capture; first black capture rejected. Exterior route/sleep PASS. Fresh pixels show veranda beam/braces meeting posts. Further plaster/roof ageing and furniture silhouette refinement remain open. These address this home; the whole world’s object support is not audited.
