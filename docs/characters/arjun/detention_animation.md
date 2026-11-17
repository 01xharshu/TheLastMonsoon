# Arjun detention animation

## Scope and behavior

2026-09-30: two states on the existing authoritative Arjun body/rig: hands-behind-back arrest and standing cell waiting. Both are six-second loops with quiet breathing; waiting adds a restrained head glance. Entry eases over 1.15 seconds, release over 0.85 seconds, and changing from arrest to waiting blends over 0.67 seconds. The planted lower body is held rather than stretching the short imported idle into a long loop with a foot snap.

The actual player scene includes `DetentionComponent`. Mission code calls `begin_detention("arrest")`, `wait_in_cell()` and `release_detention()`. The component holds the current collision-body transform, zeroes travel, stows weapons and blocks ordinary interactions. It rejects mounted/swimming/climbing/rest/river/low-stance/airborne and modal UI conflicts. The subsequent [station arrest sequence](police_arrest_sequence.md) adds local witnessed theft/assault, officer restraint and escort, a wrist cord, seated waiting, gate control and release. Confiscation, sentencing and save-state persistence remain unimplemented.

The AnimationTree blends original detention clips after ordinary locomotion layers. A rest-relative arm solve runs after the tree advances and brings wrists behind the lower back, with partial finger curl. The skeleton forward direction is +Z; an initial incorrect +Z wrist target was caught in rendered inspection and replaced with -Z. Melee/pending sword strikes cancel during detention; firearm availability, low stance, inventory and riding are gated. Entering detention stows weapons and cancels their reloads. The reserved rifle charge is returned exactly once; the pistol keeps its carried balls and current loaded rounds. This follows the shared equipment cancellation interface completed on 2026-10-01.

## Evidence

Revalidated on 2026-10-01 against the shared checkout after the pistol reload-cancellation interface was completed.

- `tools/characters/validate_arjun_detention.gd` runs the actual player in a lower DistrictPolice cell. Timed arrest entry/hold, waiting, release, recovered walking, repeated arrest/release and invalid-state rejection are covered. Pending melee cancellation, action guards and ammunition conservation on cancelled rifle/pistol reloads are checked. Explicit `ARJUN DETENTION PASS` in headless and Forward+/Metal, including the 2026-10-01 rerun after reload interface completion.
- `detention_validation.json` and `detention_validation_metal.json`: zero held actor drift, wrist gap approximately 0.161 m; both wrists checked behind the pelvis. These are wrist bone measurements, not fingertip or restraint contact approval. Final Metal capture has no script errors; shutdown reports one resource still in use, which remains a harness cleanup warning.
- `ARJUN MOTION TREE: PASS` for existing idle/walk/run/swim/sit/long-gun envelopes after the additional tree layer.
- Fresh Metal `detention_entry.png`, `detention_arrest_front.png`, `detention_arrest_back.png`, `detention_waiting.png`, `detention_release.png`. Rendered inspection confirmed wrist side, visible elbow bend and cell clearance; final art acceptance remains open.
- `detention_motion.mp4`: 14-second 30 fps Metal preview from the 2026-10-01 capture. A long stationary hold is cut; retained transition segments keep their recorded playback speed. Includes entry, hold, camera changes, arrest-to-wait, release and returned travel. Sampled transition frames inspected; this is a controlled in-world harness, not owner-controlled gameplay approval.

## Remaining work

Owner motion review and detailed finger/wrist/clothing contact remain. Officer restraint/escort, seated waiting and local crime triggers are now implemented in the linked sequence candidate. Earlier full-world runs reported FortCook/FortSteward missing skeletons; the 2026-10-01 headless detention run has no script errors. Two small original runtime clips and the existing rig add no imported texture/character assets; physical 8 GB hardware performance remains unverified.

## Seated movement refinement

The cell bench uses the existing sit and stand clips with a forward weight shift through the middle of each transition. The legs establish boot support as the hips move toward the bench. The hands reach forward during the transfer, settle onto the thighs, and lift clear again as the body straightens. The seated hold adds quiet breathing and occasional side glances.

An unarmed cart passenger looks toward each verge and returns to a forward gaze. The head turn blends with a small upper-body shift before the seat, boot and hand contacts are solved. The glance fades out when weapons or concealment take over the pose.

The detention fixture now exercises actual bench entry, seated hip and boot alignment, and release back to movement. The public cart fixture checks the seated head turn through the normal boarding path. Both use private settings and temporary review output.

```sh
python3 tools/world/run_tutorial_guard_check.py --checks validate_arjun_detention validate_public_passenger_cart
python3 tools/world/run_tutorial_guard_check.py --native --review --checks validate_arjun_detention
```

## Seated garment finish

The bench transition blends two small corrections over the original skinned outfit. The upper boot openings give the gathered trousers more room, while the lower sash panels and trim fall toward the outside of the right thigh. The sash knot stays pinned at the waist. The right hand sweeps around the outside of the hanging sash before resting on the thigh and reverses that path on the rise. The seated meshes return to their original references when the blend ends.

The station fixture checks that both boot and sash corrections engage at the bench, that the hips and soles stay aligned, and that the original meshes return on standing. Its native review renders the same seated pose with the corrections off and on. The controlled 60 Hz walk and sprint comparisons produced identical baseline and current results. Unpaced walking samples varied with frame timing.
