# Enfield cartridge insertion and ramrod contact — 2026-09-30

## Latest: 2026-10-01 — interrupted reloads

Weapon selection and stowing now cancel an active reload immediately through the equipment refresh, with an additional process guard for direct state changes. The cartridge hides, both ramrod parts return to their exact stored transforms, and the old weapon cannot finish loading in the background.

Enfield and double-gun ammunition is reserved at reload start. Cancellation clears that reservation before restoring it to inventory; repeated cancellation cannot refund it twice. Restoration emits the inventory update signal without a new-pickup notice. Existing loaded rounds are preserved. The Adams consumes ammunition only on completion, so cancellation stops its timer/click sound without a refund. A cancellation call with no active reload leaves shot playback alone.

Verification: **FIREARMS TEST PASS**, including Enfield switch/stow reservation conservation and repeated cancellation; Adams cancellation/background tick/restart; the retained 721-pose pacing/contact checks. **DOUBLE GUN: PASS**, including return of both charges and restart consumption. **METAL RELOAD INTERRUPTION: PASS**, using actual equipment toggle/selection calls, with the stowed and pistol-switch frames inspected. Evidence: `/tmp/loading_interrupt_final.log`, `/tmp/loading_double_interrupt_final.log`, `/tmp/loading_interrupt_metal.log`, `/tmp/tlm_reload_cancel_{stow,switch}_2026-10-01.png`. These are prop/state checks on the rejected temporary diagnostic body, not accepted character fit or transition-motion approval.

Model authority rechecked in `reference_fit_status.md`: the new multiview assets are separate candidates; no accepted playable replacement has been designated. Final palm/skin/sleeve/body fitting remains dependent on the accepted model. Existing twelve-second pacing remains in place.

## Latest: step 1 — reload pacing

The Enfield reload now lasts **12 seconds**, previously 5. Gameplay and visual progress share `EnfieldLoadingSequence.RELOAD_SECONDS`, avoiding mismatched timers. Quintic gesture easing gives zero velocity and acceleration at each segment endpoint; the arm solver follows these eased contacts while retaining the prop connection. This changes the existing procedural loading gestures, not an authored complete historical drill or the ready-to-loading entry pose.

| Gesture | Previous time | Current time |
| --- | --- | --- |
| Initial ramrod withdrawal and regrips | 0.80 s | 1.92 s |
| First rod turn | 0.30 s | 0.72 s |
| Typical ram-stroke regrip | 0.10 s | 0.24 s |
| Return turn | 0.25 s | 0.60 s |

Validation: **FIREARMS TEST PASS**, 721 poses at 60 fps, shared-duration startup, old-deadline non-completion, ammunition completion, cartridge alignment, phase continuity, head envelope, and exact rod reset. Maximum sampled target displacement changed from approximately 89 mm to 45 mm per 60 fps step (about 50 percent reduction). This is a target trajectory measurement, not skin contact or final motion approval. Joint contact remained within 0.016 mm in the world fixture; the Metal fixture remained within 0.001 mm.

Fresh Godot 4.7.2 Metal Forward+ capture: 361 frames at 30 fps, representing twelve seconds of playback. Insertion, turning, open regrip and ram-stroke samples inspected. Evidence: `enfield_reload_pacing_2026-09-30.mp4`, `/tmp/tlm_loading_paced_000.png` through `360.png`; logs `/tmp/loading_pacing_test.log` and `/tmp/loading_pacing_capture.log`. User review of normal-speed movement remains open. The temporary diagnostic body is still owner-rejected.

Next: accepted Arjun source/model is required for step 2 final skin, palm, sleeve and body fitting. Requested from the user; do not silently designate the rejected runtime rig as approved. Later steps remain complete loading actions, gameplay movement checks, and licensed sound timing.

## Implementation

`player/enfield_loading_sequence.gd` defines one gun-space loading path, shared by the physical cartridge, both ramrod mesh parts, and the left loading hand. The right hand supports the fore-end while the muzzle is raised. The lower loading hold keeps the muzzle and ramrod inside the loading arm's reach.

- Paper charge approaches along the bore axis and moves into the muzzle. Its folded seal disappears when insertion starts; the remaining tube disappears after insertion.
- The ramrod fully withdraws through three pulls. The rod pauses while the fingers open and slide back between pulls. During each closed pull, the contact follows a fixed point on the rod.
- The rod turns outward and forward beside the barrel, enters the bore, and makes three short downward strokes with open-finger regrips. It withdraws, turns back, and returns to its stored transform.
- The hand solver aligns the midpoint of the thumb/index distal joints to the shared contact after animation evaluation. Finger opening/closing eases through each regrip. This midpoint is a mechanical contact measure, not a skin intersection proof.
- Both ramrod parts receive the same rigid transform, preserving their connection. Stowing, switching weapons, and completing reload restore their exact original transforms. The first-person copy updates the cartridge after copying the weapon transform.

The earlier deferred BoneAttachment overwrite is also retained as repaired: the cartridge is a top-level Node3D explicitly placed after the hand/weapon pose. A prior unrelated seated parser error was repaired earlier; concurrent character/world edits remain intact.

## Verification and evidence

`tools/weapons/validate_rifle.gd` covers live-world firearm inventory, ammunition consumption, reload completion, ramrod restoration, cartridge visibility, bore alignment, 301 loading contacts, phase-boundary continuity, and a 160 mm head-joint clearance envelope during both rod turns. `tools/weapons/capture_reload_diagnostic.gd` captures the same 301 phases in Godot 4.7.2 Metal Forward+ and asserts contact after a forced draw.

Evidence is an internal mechanical diagnostic using the explicitly rejected temporary runtime Arjun asset. It cannot approve that body or its appearance. Fresh insertion, open regrip, ram stroke, turn and return frames were inspected. The 60 fps sequence represents the existing five-second reload; capture time itself can be slower than playback.

Previous five-second result: **FIREARMS TEST PASS**, including 301 poses and continuity at every phase boundary. Maximum world-fixture finger midpoint error: 0.00382 mm; Metal fixture: 0.00057 mm. These are joint-coordinate errors, not a rendered skin gap measurement. The previous five-second timing was fast: maximum sampled hand travel is approximately 89 mm per 1/60-second step during turning/regripping. Final motion pacing requires player review.

Previous logs: `/tmp/loading_test.log`, `/tmp/loading_capture.log`. Video: `docs/characters/arjun/enfield_loading_contact_2026-09-30.mp4`. Source frames: `/tmp/tlm_loading_000.png` through `/tmp/tlm_loading_300.png`.

## Remaining gates

Accepted Arjun body/rig, full-world normal-speed player review, final skin/cloth intersection review from all sides, and a historically authored complete loading drill remain open. This task adds cartridge/ramrod contact and motion; it does not add biting/powder pouring, cap placement, or claim complete historical drill approval. Police ammunition and enlarged station status: `docs/world/police_ammunition_2026-09-30.md`.
