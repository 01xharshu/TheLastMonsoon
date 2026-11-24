# Story time and route continuity worktree

These historical notes describe the source worktree and its original tests. Current integration is tracked in the [worktree ledger](../../world/worktree_integration_ledger.md).

## CODEX_HANDOFF.md


## Opening daylight / Mangal rescue / dialogue — chat 01a19d0d-0fc3-78f0-8300-ec90972d633c
Updated: 2026-11-03T03:03:08+05:30 (IST). **COMPLETE — scoped gameplay fixes and conversation baseline, proportionately verified.** Active worktree `/Users/harshmishra/.codex/worktrees/8b48/TheLastMonsoon`; no commit/push or main-checkout integration. Broader period-world art, all-pose clothing and final cinematic performance approval remain OPEN.
- Scope/result: continuous daylight after waking through tutorial/police/Chacha/training/revenge/rescue/hideout weapon lesson; free clock at `raid_ready` and `complete`, daylight during accepted first raid. Existing authored pre-waking night retained. Optional raid/next-consignment acceptance remains interaction-driven/map-marked. This is not a universal rewrite of later missions' clock policy.
- Rescue: cuts onto surveyed `fort_access` road/headings; horse/rider and cart grounded; missing physical floor stops movement. Own seated Mangal excluded from coach's clearance via existing cargo RID mechanism while riding, preserving world collision. Actual movement gate >5m and framewise support checks PASS.
- Hideout: supported approach/upper landing foundation, 22 physical masonry treads, chipped fallen verge stones, instanced chipped wall facing/fort material and earthen roof tint. No human assets/body masks changed. Broad historical/architecture refinement remains separate.
- Dialogue: shared `story/dialogue_camera.gd` + UID; Dev police/official/Chacha close coverage, mutual facing and selected POV; suppress POV below1.25m separation, room collision for recovery. Arjun talk AnimationTree overlay and Mangal restrained arm/head/facial speech/blink; restored on exit. Other world CanvasLayers hidden/restored to avoid errand-toast overlap. Reduced Mangal gesture after a larger bend exposed sleeve deformation; sampled corrected pose inspected, all-extreme cloth remains OPEN.
- Files: `story/dev_story.gd`, `rebellion_story.gd`, `rebellion_sites.gd`, `rebellion_actor.gd`, `story_pose.gd`, new dialogue helper/UID; three reusable validators; focused docs `docs/world/rebellion_sequence.md`, `story_cinematics_and_training.md`.
- Evidence: headless stage-daylight/free-clock/lessons/actual-world first/save PASS; SaveFlow14.4s. Native morning tutorial34.7s PASS (movement/HUD/paused map/horse/restore). Final exact-source snapshot parity10 scripts/UIDs PASS; incremental import1.9s, native lessons27.2s and actual-world ordered first74.4s PASS with no reported diagnostics, including near-camera/POV gates, ambient layer hide/restore, moving rescue, physical follow/briefing/training/raid/rope/delivery. Recovery, police, rescue, hideout and Mangal close/POV views inspected. All9 owned temporary snapshots/captures/logs and isolated userdata/saves removed; cleanup verified and no owned runners remain. Reusable source retained.
- Reproduce: `TLM_REBELLION_NATIVE=1 python3 tools/world/run_rebellion_integration.py --cached --native --review --checks lessons first`; stage/save/tutorial `python3 tools/world/run_rebellion_integration.py --cached --checks rebellion onboarding save`. Review snapshots auto-delete; use `review_done` after inspection. No FPS or uninterrupted manual whole-story acceptance inferred.
- Exact next action: play New Journey through hideout weapon lesson in this worktree, verify free exploration before accepting raid; broader art pass should inspect original fort-access switchbacks/undercroft roof silhouette and other world structures/props against period references, then review uninterrupted facial/cloth motion. No remaining scoped functional blocker reproduced.

## Later mission daylight and camp conversation — same chat
Updated: 2026-11-03T11:21:01+05:30 (IST). **COMPLETE — scoped later mission and hideout pass**.
- Objective: extend daylight to accepted consignment, community message and witness rescue/escort/report; retain free time while available/failed/complete. Continue close, actor-relative conversation staging at consignment camp. Preserve prior dirty opening/camera changes and other owners.
- Findings: consignment only slows clock; community missions have no clock owner. Camp praise uses distant fixed coordinates and hides only player UI.
- Changed: consignment daylight/cleanup, community message acceptance/restore/release, witness rescue/restore/failure/complete clock owner; consignment camp close/POV staging, facing/facial/gesture overlay, UI suppression/restoration. Extended consignment stage-clock/near-camera/POV/ambient regression and community owner checks.
- Import PASS85.6s; focused consignment PASS7.8s including stage daylight/free-time matrix, real shots/two waves, camp near/POV/ambient restore and once-only200rupees. Actual-world community test running with accepted/released clock owner and legacy-night restore assertions.
- Environment refinement: added collision-bearing broken roof-edge piers/parapet remnants to the existing shared chipped-stone batch; preserves entrance and walking aisle, improves the undercroft roof silhouette. Native exterior review added to consignment validator.
- Community actual-world PASS51.5s: installation/contacts, message and witness daylight owner/legacy-night restore, combat/physical escort/Continue/reward. Owned first snapshot auto-cleaned.
- Camp acting now includes the speaking companion as well as Mangal (restrained gesture/facial speech/blink, restored on finish); final source synchronized into owned native snapshot before runtime tests.
- Focused docs updated: `docs/world/rebellion_sequence.md`, `docs/world/peoples_rebel_story_outline.md` describe accepted/available/failed/completed clock ownership and camp/roof changes.
- Native consignment actual-world PASS75.9s: actual police hits, player shots/two waves, stage clocks, near/POV camp and ambient restore/reward; camp/exterior views inspected. Exterior still exposed a long inclined deck. Replaced its visible surface with solid terrain-supported masonry treads (retaining smooth under-collision). This last approach refinement requires original mission/native exterior rerun.
- Final native first mission PASS217.8s on synchronized stair source after incremental import PASS4.3s. Inspected the visible masonry treads, broken roof piers and parapet. Grounded rescue, follow, briefing, raid and delivery passed. No scoped blocker. Broader architecture and uninterrupted acting/clothing review remain open.
- Verified cleanup of all three owned snapshots and isolated save directories.
- Reproduce with `TLM_REBELLION_NATIVE=1 python3 tools/world/run_rebellion_integration.py --cached --native --review --checks world first`. Next: normal play from first rifle delivery into optional consignment, then community, checking free time before accepting each mission and reviewing clothing and contact in continuous motion.

## Concealed hideout entry
Updated: 2026-11-03T21:40:59+05:30 (IST). **COMPLETE — stair removal and screened approach verified.**
- User rejected exterior realism and requested removal of entry stairs and proper broken walls.
- Next: replace elevated access with terrain approach around collapsed curtain wall, migrate old follow saves, run disposable first mission verification.
- Implemented ground-level flank breach, screened doorway, broken colliding stone courses, and versioned follow-route migration. Running native actual-world first mission and exterior review.
- Added reusable old-stair checkpoint migration and actual doorway-occlusion assertions. Current native snapshot began before these assertions, so a second focused actual-world run will exercise them.
- Native first attempt FAIL50.3s: Mangal at route index1 blocked by PopulationExpansion Colleague_fort_access BodyCollider. Move wall off the public lane, ground exterior movement each step, and allow passing traffic a bounded clearing interval.
- Headless actual-world rerun reached briefing, raid and delivery and passed legacy stair-save migration. Sole failure was the straight sightline test. Raising the surviving central wall courses and filling below the short threshold before final native rerun.
- Final native command: TLM_REBELLION_NATIVE=1 python3 tools/world/run_rebellion_integration.py --cached --native --review --checks first. Includes migration and wall sightline checks, then exterior review.
- Final snapshot `tlm-ordered-rebellion-qumllq6m` imported successfully in 88.0s. Native first mission running. Updated the focused route documentation to supersede the exterior stair design.
- Raised wall passes the doorway sightline check. Native route still stalls on the same resident before the breach after waiting, so adding bounded collision-checked sidesteps to Mangal’s exterior follow movement.
- Synchronized the sidestep source into the owned imported snapshot. Final native snapshot tlm-ordered-rebellion-8kcspnb3 incremental import PASS2.3s. First mission and visual review pending.
- Final native first mission PASS77.4s including sightline, legacy migration and follow. Its automatic review window expired before inspection. Re-running for exterior inspection.
- Final repeat native PASS113.8s, including collision-checked follow, wall sightline and old-save relocation. Inspected exterior capture. The short supported threshold and rectangular chamber roof still read angular from the elevated view. Broader terrain blending and roof silhouette remain open. Next: review threshold and roof from normal player-height approach before any further art changes.

## Hideout earthwork and roof silhouette
Updated: 2026-11-03T21:53:43+05:30 (IST). **COMPLETE — hideout earthwork and silhouette pass.**
- Replace angular earth banks and flat cap with terrain-sampled mesh surfaces. Verify approach and native exterior.
- Implemented terrain-sampled threshold with feathered shoulders and irregular buried roof crown, with shared render/collision surfaces. Starting native first-mission regression.
- First native mission PASS130.8s. Exterior review found steep roof shoulder and flat color still separated from terrain. Widening feather, tapering the front corners outside the doorway, and reusing the world terrain material. Added player-height review capture.
- Active final native snapshot tlm-ordered-rebellion-2ltvy_vf, synchronized geometry and two exterior camera views. Command: TLM_REBELLION_NATIVE=1 python3 tools/world/run_rebellion_integration.py --cached --native --review --checks first.
- Native terrain-material pass PASS101.9s. Elevated view blends into hillside. Player-height view exposed underside void below chamber and abrupt edges at doorway cut. Adding grounded foundations and masonry returns, then rechecking both views.
- Final foundation/return snapshot tlm-ordered-rebellion-6azx3aym incremental import PASS4.4s. Running native first mission and eye-level/elevated review.
- Final native FIRST PASS93.9s with no reported diagnostics. Inspected both eye-level and elevated views. Foundation closes the underside void, stone returns support the tapered doorway cut, and the roof crown uses the native terrain material. No scoped blocker. Next: normal play from fort arrival through the breach for owner art review.

## docs/world/peoples_rebel_story_outline.md


### Daylight ownership — 3 November 2026

Accepting Mangal's message holds daylight until delivery to Chacha. Accepting the witness mission holds daylight through rescue, physical escort and safety confirmation; completion/failure releases its owner. Available leads and completed chapters allow normal time. Restore derives these owners from saved stages and corrects older night checkpoints using GameTimeSystem's existing forward-only daylight normalization. Owners release on scene exit. These clock changes retain actual combat/escort, consent/interaction gates, save/Continue, identity and once-only reputation behavior.

## docs/world/rebellion_sequence.md


## Opening daylight and grounded rescue — 2 November 2026

The mandatory opening holds the game clock from waking/tutorial through police inquiry, Chacha recovery and all eight lessons. The authored pre-waking night sequence remains intact. Revenge, escape, Mangal rescue, arrival, hideout conversation and weapon practice also hold daylight. Restoring these stages from an older night save moves forward into daylight using the existing clock API. Finishing Mangal's target practice enters `raid_ready`: time resumes and the player may explore before interacting with Mangal to accept the raid. The accepted raid holds daylight through delivery; `complete` releases it. Existing map destinations identify available work; proximity alone does not accept the raid or subsequent consignment.

Rescue cuts place horse and coach on the existing `fort_access` road with its surveyed heading, rather than preserving an arbitrary cross-country player heading. The horse/rider and coach follow the ground; cinematic cart steps require physical floor and existing clearance. Arrival reuses the final fort-access segment. The approach to the undercroft retains its walkable surface and now has terrain-sampled retaining masonry below it, with shared chipped fallen stones at the verges. The landing is filled to its base; the descending passage has physical masonry treads; wall faces reuse instanced chipped stone and the fort material, and the roof cap uses an earth tint. These are focused construction changes, not a whole-world historical/art approval. Masonry direction is consistent with historic Indian stone/rubble and lime-mortar construction; see the National Mission on Monuments and Antiquities description of [Bhimgarh/Reasi Fort](https://nmma.nic.in/nmma/builtDetail.do?dynasty=47&refId=2394), built in its later form during 1817–1841. This is a material/construction reference, not a claim that the fictional hideout reproduces that fort.

Reusable checks: `python3 tools/world/run_rebellion_integration.py --cached --checks rebellion lessons first save`. Native actual-world view: `TLM_REBELLION_NATIVE=1 python3 tools/world/run_rebellion_integration.py --cached --native --review --checks first`. The disposable snapshot isolates saves and removes all captures/logs on exit. Current results and remaining work are recorded in `CODEX_HANDOFF.md`.

Verification, 3 November 2026: final native exact-source snapshot passed incremental import (1.9 s), Dev/lessons (27.2 s) and populated-world ordered first mission (74.4 s), including near-Arjun/POV framing and ambient UI hide/restore. Native recovery, police, Mangal close/POV and rescue views inspected. Earlier scoped stage-daylight, tutorial and SaveFlow checks passed. Broader uninterrupted performance, all-pose cloth and whole-world period art remain open. Disposable images/logs/test saves removed after review; reusable validators retained.

## Later mission daylight and camp coverage — 3 November 2026

The accepted consignment now holds daylight throughout outbound travel, loading, pursuit and camp celebration. Dormant/available (`assigned`), failed/retry and completed states release that mission's clock owner. Save restoration reapplies the owner from the saved mission stage and advances legacy night checkpoints into daylight. Other active missions keep their own locks; one mission finishing never releases another's lock. Ordinary side jobs and resident schedules retain their existing time policy.

Camp praise uses the shared Arjun-relative camera with close shoulder coverage and a deliberate POV section. Companion and Mangal face Arjun and use restrained speech/blink/hand/head motion, restored after the conversation. Non-owned world UI is hidden/restored so ambient errands cannot cover the subtitles. Original two-wave combat, once-only200rupees, save/restore and ambient traffic behavior remain intact. Roof-edge broken piers and parapet remnants reuse the hideout's shared chipped-stone batch and have physical collision.

Community acceptance follows the same boundary: the delivered-message mission holds daylight only between accepting Mangal's offer and delivery to Chacha; witness rescue/escort/report hold daylight until confirmation or failure. Available leads do not freeze time. Restoring active message/witness stages reapplies daylight, including legacy night saves. Current checks and remaining visual gates are in the root handoff.

The final exterior approach uses 20 terrain-supported masonry treads above the smooth collision base. Native exterior inspection and the full first-mission regression passed on the revised staircase. The native consignment and actual-world community regressions also passed.

## Concealed hideout approach

The exterior staircase and upper landing described above were replaced by a ground route through a flank breach in the ruined curtain wall. Surviving wall courses screen the chamber doorway. The route turns behind the wall and rises along a short, supported earth threshold to the chamber floor. Mangal follows the terrain outside and yields to actors crossing the fort road. A save from the old follow route resumes with Arjun and Mangal at the ground approach. The follow stage and mission progress are preserved.

The hideout threshold and roof now use terrain-sampled meshes with the world terrain material. The roof crown tapers into the hillside, a masonry foundation closes the gap below the chamber floor, and broken retaining returns flank the earth approach. Native first-mission verification and elevated and eye-level visual inspection passed on the final geometry.

## docs/world/story_cinematics_and_training.md


## Arjun-centered conversation coverage — 3 November 2026

Police reception, office dialogue and Chacha's optional/recovery conversation now use `story/dialogue_camera.gd`: actual animated head-bone eye positions, close coverage around Arjun, a consistent side of the conversation axis and selected per-line POV cuts. Both participants face each other. POV is suppressed when participants are too close, and room collision constrains recovery coverage too. Physical travel, violence, carrying and drinking retain their action staging.

Arjun's speech uses a restrained `talk` overlay in the existing AnimationTree story branch, weighted by speech and stronger for objection. Existing concern, anger, disdain, speech and blink layers remain situation-dependent. Mangal's briefing adds an over-shoulder → POV → over-shoulder structure, mutual facing and modest arm/head/facial speech motion, restored on exit. This is subtitle-timed acting; it does not establish recorded-voice lip synchronization or final garment deformation approval.

Reusable check: `TLM_REBELLION_NATIVE=1 python3 tools/world/run_rebellion_integration.py --cached --native --review --checks lessons first`. Disposable close/POV views are removed on exit. Current verification and unresolved visual findings remain in the root handoff ledger.

Verification, 3 November 2026: final native exact-source snapshot passed incremental import (1.9 s), Dev/lessons (27.2 s) and populated-world ordered first mission (74.4 s), including near-Arjun/POV framing and ambient UI hide/restore. Native recovery, police, Mangal close/POV and rescue views inspected. Earlier scoped stage-daylight, tutorial and SaveFlow checks passed. Broader uninterrupted performance, all-pose cloth and whole-world period art remain open. Disposable images/logs/test saves removed after review; reusable validators retained.
