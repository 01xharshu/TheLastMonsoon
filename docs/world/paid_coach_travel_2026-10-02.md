# Paid coach travel — 2026-10-02

Arjun boards the covered family carriage as a passenger and selects a destination. The first gameplay fare is a flat 2 rupees; this is a tuning value, not a historical price claim. Stops: Bhairavpur, Town Hall, Government House, Police Station, Company Compound and Hooghly Port.

## Implemented

- Single booking charge, insufficient-funds rejection, cancellation/dead-horse/exit refund, eight-second obstruction refund, and arrival without a second charge.
- E reopens destination choices while seated. The map uses the same paid booking flow for nearby named stops. A square » button skips the remaining journey only when the destination has ground and cart clearance.
- Cart save data retains the paid destination; restore resumes without another deduction and refunds if resume fails.
- Destination choices use square panels, translucent dark backgrounds and no decorative stroke. Names and fare identify the choices; close/skip use symbols.
- Main timber bridge deck widened from 4.8 to 6.0 metres, including rail/post/ramp spacing and supports.

## Evidence

- `tools/horses/validate_paid_coach.gd`: explicit PASS for funds, single charge, short actual-controller arrival, duplicate rejection, skip, cancellation, connected stop graph, paid state collection/restore/resume and stalled-trip refund. A subsequent dedicated disk save/load also passed; details below.
- `tools/horses/validate_cart_bridge.gd`: all three actual carts crossed both ramps and deck in both directions, explicit PASS. Uses accelerated 0.1-second controller steps in an isolated physics fixture. Single-horse variants have uneven forward progress and need normal-speed ramp review.
- Full Suryagarh paid Government House → Town Hall: explicit PASS; 417.28 m displacement, final road waypoint error 1.86 m, 5 → 3 rupees. Actual physics at 60 Hz, headless; no human motion acceptance. First world load exposed a cattle caretaker type-inference error; explicit Vector3 annotation fixes it.
- Inspected Forward+/Metal [bridge clearance](captures/cart_bridge_clearance.png) and [destination menu](captures/paid_coach_destination.png). These are isolated views; coachman now reuses the existing Blender MPFB village farmer.

## Open checks

Full Suryagarh paid Government House → Police Station across the bridge: explicit PASS; 607.16 m displacement, final road waypoint error 1.93 m, 5 → 3 rupees. No cattle parse error on this rerun.

Remaining destinations, normal-speed visual passenger/coachman motion, coachman cloth/seat contact and full disk save/load require review. Documentation gate currently reports existing missing capture links in the shared docs index; this task does not replace those unrelated captures.

## MakeHuman requirement and driver replacement

The universal rule is recorded in root `AGENTS.md`: all humans and human placeholders must use Blender MakeHuman/MPFB, or reuse an existing character from that workflow. The primitive coachman body, legs, head, turban and arms were removed from the family carriage builder.

The replacement uses `WorkingAssets/NPCs/village_farmer/village_farmer_rigged_candidate.glb`, authored by `tools/characters/build_village_farmer.py` through MPFB. `vehicles/seated_coachman.gd` reuses the household NPC AnimationTree, seats the pelvis, solves both palms to the rein grips and curls fingers. It hides when Arjun drives. Occupied household coaches retain their own existing MakeHuman drivers. This is an existing human candidate reused as a driver, not a newly approved driver identity.

Fresh [MakeHuman coachman close view](captures/makehuman_coachman_grip.png) captures seat and rein contact. Both palm residuals were 0.89 mm in the static capture. The inspected image shows the reused human seated with hands at the rein grips; clothing around the lap and continuous driving motion still need refinement. Numeric contact and static rendering do not establish final cloth or driving-motion realism.


## Unified travel and disk round trip — 2026-10-05

Paid coach travel is the single passenger journey controller. The map and seated E menu both use `paid_coach_travel.gd` / `coach_routes.gd`; manual cart driving retains the shared collision and road-height probes. Removed the inactive free-coordinate prototype (`cart_journey.gd`, `cart_road_route.gd`) and its failed duplicate runner; the retained replacements are the paid controller, stop graph, `validate_paid_coach.gd` and `validate_paid_coach_live.gd`. Reference search found no remaining calls to the retired scripts. Editable character sources and current visual evidence were retained.

`validate_paid_coach.gd` now writes and reads an actual JSON save in a dedicated test directory, changes the cart position and inventory, applies the disk save, and verifies cart position, passenger occupancy, paid destination, one fare deduction and subsequent cancellation refund. It restores the original save directory and removes only the test save. This uses the real SaveManager and player in an isolated fixture; it does not claim a new full-world cold scene-load pass. Initial disk attempt failed because the earlier obstruction test had disabled boarding physics; the fixture now enables it before loading.

Latest clean runtime evidence: `/tmp/tlm_paid_coach_unified_oct05.log`, `/tmp/tlm_paid_coach_disk_recheck_oct05.log`. Both print explicit PASS; no script errors. The 417 m Town Hall and 607 m Police Station world-route results above remain the recorded long-route evidence. Remaining stops, normal-speed road/bridge motion, clothing contact and full-world cold loading remain open.

## Coachman footboard and driving response — 2026-10-05

`seated_coachman.gd` now solves both ankles to targets attached to the existing footboard after seating the pelvis. Targets were moved inside the leg's reachable range; the first forward target produced an 8.9 cm reach limit and was rejected. The initialization guard waits for the existing leg solver to be configured. Acceleration/braking pitch and turning twist ease over time; a small breathing offset is blended rather than moving the seated pelvis. Palm solving runs after torso and leg posing, retaining both rein contacts.

`capture_coachman_motion.gd` exercises idle, acceleration, turning and braking at 60 Hz with driving signals applied to a stationary carriage. It disables the carriage controller for this isolated pose trial so those signals are not overwritten. Explicit `COACHMAN DRIVING CONTACT METAL PASS`: maximum palm residual 0.96 mm; ankle target residual zero at sampled states; settled acceleration lean .232 rad, braking .135 rad, turn twist .055 rad. These are contact/response checks, not a full road-motion review or proof of mesh sole contact.

Fresh Forward+/Metal close [idle](captures/coachman_motion_idle.png), [acceleration](captures/coachman_motion_accelerating.png), [turn](captures/coachman_motion_turning.png), [braking](captures/coachman_motion_braking.png), and [contact view](captures/makehuman_coachman_grip.png). Turn/braking views inspected: human geometry retained, feet remain over the board, hands remain beside the grips. Lap clothing, finger/thumb wrap, mesh sole contact and normal-speed continuous world motion remain open. Measurements: `coachman_motion_validation.json`.

Paid fare/arrival/skip/blocked refund plus actual disk SaveManager round trip rerun: explicit PASS. Godot reports retained-object/resource warnings at fixture teardown; do not label it a warning-free run. No new full-world route result is claimed by this pose pass.

## Existing dhoti seated fit and moving trial — 2026-10-05

`coachman_seated_cloth.gd` reuses the two existing exported dhoti surfaces (wrapped garment and woven border), retaining their topology, UVs and materials. The standing garment is reformed along the seated pelvis-to-knee line. The MakeHuman body mesh, rig, source GLB and editable Blender source remain unchanged. The loose kurta panel retains the existing hidden state; an attempted lap adaptation of that panel produced a flared waist and was rejected.

The fitted garment stays attached to its wearer through the existing mesh hierarchy and rebuilds only when local knee position changes by more than 0.5 mm. `capture_coachman_cloth_drive.gd` drove the actual paid passenger controller at 60 Hz for 300 physics steps on the actual isolated bridge: `COACHMAN CLOTH MOVING BRIDGE METAL PASS`, 43.875 m displacement, two retained garment meshes, one cloth rebuild. Both hands and ankles remained within 2 cm of the current vehicle-local contact targets. The first moving contact assertion sampled an old world-space target after the vehicle had advanced; validation now derives the foot target from the current cart transform.

Inspected [moving cloth view](captures/coachman_cloth_moving_bridge.png) and refreshed [close fit](captures/makehuman_coachman_grip.png): the lower garment follows the lap and knees rather than hanging as a standing shell. The hem/folds remain angular and need finer source tailoring; waist overlap, hand/rein routing and cloth-to-skin clearance remain art checks. This is a short isolated bridge motion trial, not a new full-world route approval.

Paid gameplay and actual disk save/load regression rerun: explicit PASS; shutdown resource warnings remain. One overlapping native capture encountered Metal fence timeouts; the retained moving trial completed without those errors. Controlled motion captures were refreshed sequentially: explicit Metal contact PASS for all four states; refreshed turning view inspected.
