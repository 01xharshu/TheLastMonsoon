# Arjun detention animation

## Scope and behavior

2026-09-30: two states on the existing authoritative Arjun body/rig: hands-behind-back arrest and standing cell waiting. Both are six-second loops with quiet breathing; waiting adds a restrained head glance. Entry eases over 1.15 seconds, release over 0.85 seconds, and changing from arrest to waiting blends over 0.67 seconds. The planted lower body is held rather than stretching the short imported idle into a long loop with a foot snap.

The actual player scene includes `DetentionComponent`. Mission code calls `begin_detention("arrest")`, `wait_in_cell()` and `release_detention()`. The component holds the current collision-body transform, zeroes travel, stows weapons and blocks ordinary interactions. It rejects mounted/swimming/climbing/rest/river/low-stance/airborne and modal UI conflicts. No automatic police arrest trigger, crime rules, escort AI, confiscation, sentence or save-state persistence is added by this animation task. Waiting is standing; a seated platform pose remains a separate contact task. No handcuff/rope prop or officer hand contact is claimed.

The AnimationTree blends original detention clips after ordinary locomotion layers. A rest-relative arm solve runs after the tree advances and brings wrists behind the lower back, with partial finger curl. The skeleton forward direction is +Z; an initial incorrect +Z wrist target was caught in rendered inspection and replaced with -Z. Melee/pending sword strikes cancel during detention; firearm availability, low stance, inventory and riding are gated. Entering detention stows weapons and cancels their reloads. The reserved rifle charge is returned exactly once; the pistol keeps its carried balls and current loaded rounds. This follows the shared equipment cancellation interface completed on 2026-10-01.

## Evidence

Revalidated on 2026-10-01 against the shared checkout after the pistol reload-cancellation interface was completed.

- `tools/characters/validate_arjun_detention.gd` runs the actual player in a lower DistrictPolice cell. Timed arrest entry/hold, waiting, release, recovered walking, repeated arrest/release and invalid-state rejection are covered. Pending melee cancellation, action guards and ammunition conservation on cancelled rifle/pistol reloads are checked. Explicit `ARJUN DETENTION PASS` in headless and Forward+/Metal, including the 2026-10-01 rerun after reload interface completion.
- `detention_validation.json` and `detention_validation_metal.json`: zero held actor drift, wrist gap approximately 0.161 m; both wrists checked behind the pelvis. These are wrist bone measurements, not fingertip or restraint contact approval. Final Metal capture has no script errors; shutdown reports one resource still in use, which remains a harness cleanup warning.
- `ARJUN MOTION TREE: PASS` for existing idle/walk/run/swim/sit/long-gun envelopes after the additional tree layer.
- Fresh Metal `detention_entry.png`, `detention_arrest_front.png`, `detention_arrest_back.png`, `detention_waiting.png`, `detention_release.png`. Rendered inspection confirmed wrist side, visible elbow bend and cell clearance; final art acceptance remains open.
- `detention_motion.mp4`: 14-second 30 fps Metal preview from the 2026-10-01 capture. A long stationary hold is cut; retained transition segments keep their recorded playback speed. Includes entry, hold, camera changes, arrest-to-wait, release and returned travel. Sampled transition frames inspected; this is a controlled in-world harness, not owner-controlled gameplay approval.

## Remaining work

Owner motion review, detailed finger/wrist/clothing contact, officer restraint/escort animation, seated cell waiting, and a mission/crime integration remain. Earlier full-world runs reported FortCook/FortSteward missing skeletons; the 2026-10-01 headless detention run has no script errors. Two small original runtime clips and the existing rig add no imported texture/character assets; physical 8 GB hardware performance remains unverified.
