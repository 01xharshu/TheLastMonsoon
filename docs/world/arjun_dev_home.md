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
