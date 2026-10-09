# Arjun window traversal — 2026-09-30

Space, the existing jump/climb control, starts a 3.2-second traversal when Arjun faces a nearby registered open window. He reaches the sill, lifts the lead leg, lifts the trailing leg, crosses with his torso lowered beneath the lintel, and descends onto the far-side floor. Palm targets follow the sill; boot targets lift above it before crossing. The sequence uses the selected runtime rig and procedural bone poses rather than an imported window animation.

The eight side openings on Bhairavpur houses 4, 11, 19 and 28 are registered. Entry works from either side. The route requires a clear opening, a supporting floor and room for the standing player at the landing. Closed shutters, grilles and obstructed landings are rejected. The existing wall step climb remains a separate route. `player/window_climb.gd` owns the window path and pose; `ClimbComponent` routes input and the visual layer invokes it.

Evidence: lead leg (test output deleted), trailing leg (test output deleted), and 3.2-second Metal motion preview (test output deleted). The movie advances the actual traversal at fixed 30 Hz and renders every frame in a physical aperture fixture. It is a repeatable motion diagnostic, not player-driven full-world footage.

Historical checks from `tools/characters/validate_arjun_window_climb.tscn` cover both directions, sampled boot/head frame clearance, collision restoration, supported landing, blocked landing and closed shutter rejection. They test bone clearance; cloth/boot mesh margins and fingers need closer review. Current world behavior checks are recorded below. Full-world player camera, continuous stone contact and final animation realism remain open. The temporary character appearance is not approved by this work.

Current checks retain reusable test code without captures, logs or generated reports.

## Gate and shutter recovery — 2026-10-07

2026-10-08 player report follow-up: Bhairavpur courtyard gates now permit an exterior latch action even when night or manual locking is active. The secondary interaction locks or releases the manual lock from outside. After opening, a 12-second idle timer closes the leaves when the swept path is clear; the lock remains usable, and E can reopen from outside. The latch action retreats the player before opening so a body beside the pull does not block both swing directions. A fresh isolated native Forward+/Metal Player test passes manual outside lock → E reopen → automatic close and retained lock, plus scheduled night lock → E reopen. The placed world gate still needs normal player review.

The estate entrance gate uses the same exterior latch and idle close. Manual lock state is included in door save data and restored against the current opening hours. The access recovery scene now passes headless and native Forward+/Metal checks for player exterior lock/reopen/auto-close and actual placed courtyard gate setup. A JSON save-data round trip now preserves the closed manual lock, and restoring it leaves the gate reopenable. A complete save-slot restart and normal player review in the populated world remain open.

An open, registered side window now has an actual one-press input check: one Space press starts and completes the crossing in both directions with no second press, lands beyond the sill, and restores player collision. Headless and native Metal isolated input checks pass. Closed shutters and blocked landings reject the crossing from both sides; an open window and a clear landing are still required. No screenshots or logs were retained.

Side windows with timber shutters now register traversal portals; the physical closed leaves still prevent crossing. Iron grilles remain blocked. Open shutters with E from inside, face the side opening within about one metre, and press Space once to cross; window traversal no longer waits for a second jump at the sill. Rear apertures are smaller and remain outside this traversal registration. Night latches restrict outside entry while permitting inside egress; the schedule closes doors at the closing transition rather than every minute. Dawn unlocks scheduled doors. Blocked opening swings try the opposite direction without disabling collision.

Focused checks: `Godot --headless --path . tools/world/validate_access_recovery.tscn` covers rotated side checks, night egress, morning unlock and alternate opening swing. `Godot --headless --path . tools/characters/validate_arjun_window_climb.tscn` covers collision, landing and hinged-shutter traversal. No test captures or reports retained. Full populated-world camera, moving garment/contact and owner play acceptance remain open.

## Both-direction logic follow-up — 2026-10-08

The route preserves Arjun's lateral position within the opening. This permits a clear part of the window to be used when furniture blocks its centre, while still rejecting the blocked strip. Every ray and landing probe uses the player's collision mask. Closed shutters, iron grilles, an unsupported landing and insufficient standing room prevent entry from either side.

An accepted sill catch consumes the jump's catch timer. Completing a crossing cannot trigger another climb without a fresh Space press. If movement is blocked for 0.45 seconds, or standing collision cannot be restored at the landing, window traversal reverses along the same collision-checked path to the departure side. A blocked return waits for clearance; backward input still releases the grip. Grip release uses the side Arjun currently occupies, so cancellation or injury after passing the sill pushes away from the wall rather than back into it. World collision remains enabled during crossing and recovery.

Current results:

- `validate_window_single_press.gd`: both directions; closed, blocked and unsupported landings; moving route and standing-space obstruction with safe return; release before and after crossing the sill; fresh-press requirement. Headless PASS; four ObjectDB exit leaks remain in this isolated fixture.
- `validate_window_house.tscn`: real settlement builder geometry, rotated house, both east/west openings, both directions with normal Space input, actual closed/open timber shutters and grille exclusion. Headless and native Forward+/Metal PASS. A live rendered crossing was inspected; this does not approve final clothing/finger contact.
- `validate_arjun_window_world.tscn`: populated Suryagarh, 46 registered openings, all eight permanently open windows crossed both ways. Headless PASS with collision/state restoration.

In game, open the shutters with E from inside if necessary, face a clear side-window opening from either side at about one metre, then press Space once. Use another clear strip of the aperture if furniture occupies the landing. Smaller rear windows and iron grilles remain unavailable. No test images, recordings, logs or reports were retained.

## Sill contact and garment follow-up — 2026-10-08

Window pose now lowers the torso and brings the shoulders within arm reach before solving the palms. Both palms face down onto the sill, travel across its depth, and release after the torso crosses. The leading boot lowers earlier toward the far floor. Hand bases are normalized before interpolation; the normal-input route no longer emits quaternion conversion errors.

A temporary 35 mm radial hip ease uses the existing tunic vertices and weights during the deep lift. Complete body and opaque foundations remain intact. The original tunic mesh returns on landing and grip release; both restoration routes are checked. The narrow hip slit was absent in the inspected close views. The broad rigid black hem, sleeve/sash edges and carried-pouch presentation still need visual refinement; this is not final clothing approval.

Fresh checks after these changes: single-press logic and garment release restoration PASS; real rotated-house normal Space input in both directions native Forward+/Metal PASS; manual rendered pose fixture palm support/orientation, head/boot clearance, landing and garment restoration PASS. Full-support palm targets were within 0.000001 m of the solved palm points, downward alignment at least 0.976. These are bone/contact measurements, not skin-surface acceptance. The real-house test reports six ObjectDB instances and one resource at exit; the single-press fixture reports four ObjectDB instances. No gameplay script errors appeared in the final runs. The manual reviewer now advances the equipment attachment after each sampled pose. Diagnostic views were inspected and deleted from OS temporary storage.

Gate access recovery also passes the serialized manual-lock restore check. A full save-slot restart remains a separate gate. Continue with normal-speed player-camera review and the remaining rigid garment/pouch edges; do not promote final realism from the focused checks.

## Gameplay camera and real slot follow-up — 2026-10-08

The real-house reviewer now aligns the existing gameplay camera with the approach direction, just as turning toward the window does in play. Optional temporary views sample two normal-speed Space crossings from the player camera. Fresh native Forward+/Metal checks PASS without reported exit leaks; Arjun remains visible in the inspected middle-crossing frames from both sides. This fixture uses real settlement architecture but does not replace populated-world player review. The camera fixture writes nothing by default; a caller-provided OS temporary directory is cleaned after inspection.

The window-only alternative hem weighting was rejected after native inspection showed a pointed flap; it is not retained. Existing radial hip ease remains. The pouch follows the animated waist in the latest close views. Rigid cloth and sash deformation are still art defects, not approved by this review. Shared stance assets were not changed or rebuilt because the shared clothing inputs were preserved.

`validate_access_recovery.tscn` now optionally uses `TLM_GATE_SAVE_TEST_DIR` to exercise SaveManager's actual slot writer/reader in an OS temporary directory. A fresh headless run passes real slot write/read and closed manual-lock restoration, plus outside reopening and auto-close in the same access suite, with no reported exit leaks. All temporary slot data was deleted. This closes file-backed persistence verification; rebuilding the populated world through Continue is still untested in this focused fixture.

## Gathered cloth and fresh-world Continue — 2026-10-08

The window-only garment correction now has a bounded, normalized blend shape: the lower tunic gathers up to 85 mm and narrows gently during the deep leg lift. Sash tails and their trim gather up to 55 mm with a small curved fold. The waist stays pinned. The fold eases in at progress .16–.38 and out at .68–.90; original meshes restore after landing/release. This uses existing garment vertices, skin weights, materials and complete body/foundations. Shared clothing/shader/ground-stance inputs are unchanged. It is a local corrective pose, not cloth simulation or final art approval. Final native close views inspected in both directions show a shorter gathered hem and curved sash; the existing blocky trouser silhouette and fine drape remain visual limitations. A first blend-mode candidate produced severe distortion, was fixed to explicit normalized blending, and is not an accepted result.

Reusable reviewer checks now assert normalized blend mode, vertex-count preservation, fold displacement below 100 mm, deep-crossing fold activation, and original tunic/sash restoration on both landings. Fresh headless pose and single-press/release checks PASS; headless pose fixture still reports nine ObjectDB instances/two resources at exit, single-press four ObjectDB instances. Native Metal pose PASS with no reported exit leaks. Temporary captures were deleted.

`tools/world/validate_gate_continue.gd` passed the actual SaveManager Continue path: save a placed locked courtyard gate, change to a fresh populated Suryagarh scene, consume the pending slot, restore the closed manual lock, open from outside and close automatically with the lock retained. This headless test verifies world reconstruction and functional persistence, not the visual menu experience. Save files lived in caller-owned OS temporary storage and were removed in finally. No gameplay errors or exit leaks were reported in that run.

Final integration: native Forward+/Metal real-house normal Space input PASS after tunic/sash folds, both directions, shutter/grille rejection and standing collision restoration; no exit warnings reported. The manual reviewer also advances pouch cloth support each fixed step to avoid stale-frame leather deformation. Fine trouser/sleeve drape and normal-speed populated-world art acceptance remain open.

## Main-game integration confirmation — 2026-10-09

The shipped `player/player.tscn` uses ClimbComponent and ArjunVisual. The normal jump catch selects WindowClimb; ArjunVisual invokes its pose, including WindowClimbClothing. Bhairavpur's settlement builder registers 46 current side-window portals (including shuttered openings), with eight permanently open side windows. Placed courtyard gates opt into outside latch access and 12-second idle closing. These are production-world settings, not fixture-only behavior.

`validate_arjun_window_world.tscn -- --single-window` now exercises normal Space input in the populated Suryagarh scene, rather than calling the traversal directly. Fresh headless PASS: 46 registered; BhairavpurHouse4 placed window crossed inside/outside, garment fold exceeded .9 in the deep lift, original tunic and standing collision restored. Exit 0; no diagnostics reported. Full eight-window normal-input run exceeded 240 seconds under populated-world cost and is not a pass; the existing all-eight direct-route result is historical. The reusable input reviewer now allows floor contact to settle after test teleporting. Native real-house rendering/normal-input checks are recorded above; this new populated-world run is functional, not rendered or performance approval. No test output files retained.
