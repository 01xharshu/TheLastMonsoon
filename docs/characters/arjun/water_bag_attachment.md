# Water pouch attachment and relaxed hand clearance

Updated: 2026-09-30

The worn pouch uses the shared household pouch scene, on Arjun's rear hip. Its loop is pinned to the animated pelvis/sash attachment. Movement tilts the lower pouch around that fixed loop; filling expands the outer face while keeping the inward face against the clothing support plane.

Actual inventory water drives the shape: 0 L is flattened and creased, 1 L partly expanded, 2 L full. The runtime mesh has a smooth leather silhouette, grain, stitched edges, carry loop and wooden stopper. Shared source resources and mouth/grip markers are retained. Mesh rebuilding occurs during water changes, not every idle frame.

## Hand correction

Ordinary stowed-weapon locomotion now routes relaxed palms outside conservative coat/trouser envelopes, including room for fingers. The wrist retains its incoming world orientation during the arm solve, with a relaxed neutral-relative angle limit of 0.85 radians. Contact actions retain their own targets. Both equipment and fruit arm solvers use the difference between limb lengths plus 35 mm as a minimum reach, avoiding a nearly folded singularity. Full reach is retained after the fruit regression caught lost contact.

## Evidence

- [Metal empty view](water_bag_fit_2026-09-30/empty_back.png), [half view](water_bag_fit_2026-09-30/half_back.png), [full view](water_bag_fit_2026-09-30/full_back.png).
- [Running](water_bag_fit_2026-09-30/motion_run.png), [turning](water_bag_fit_2026-09-30/motion_turn.png), [measurements](water_bag_fit_2026-09-30/review.json).
- [World empty](water_bag_fit_2026-09-30/world_empty.png), [world full](water_bag_fit_2026-09-30/world_full.png), [ordinary world movement](water_bag_fit_2026-09-30/world_walk.png).

Godot 4.7.2 Forward+/Metal 4.0, Apple M4. Captures use actual Player input at normal time scale for walk/run/turn/stop. Water bag waist validation PASS (inventory, pinned loop, turn, bounded sway and removal). Mango reach PASS. Firearms test PASS, including 721 loading contact poses. World startup still emits the separately tracked FortCook/FortSteward skeleton errors.

Final rendered locomotion sweep: minimum palm envelope margin stayed positive (walk 2.6 mm, run 15.6 mm, turn 10.8 mm, stop 11.8 mm); maximum relaxed wrist angle was 0.534 radians. These values include the conservative hand-width allowance.

## Remaining review

Envelope measurements are conservative clearance checks, not triangle-level cloth collision. Close rendered samples were inspected for the worn pouch and ordinary locomotion. A coat-hem intersection with the lower pouch appeared in an intermediate moving sample; it did not appear in the final turn endpoint, but continuous cloth/pouch contact remains open. Swimming, climbing, mounted transitions, every item-use pose and every combat pose still require their own continuous visual review. This does not approve the owner-rejected overall Arjun appearance or establish that all possible hand contacts are free of clipping.
