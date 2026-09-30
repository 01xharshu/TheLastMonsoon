# British NPC AnimationTree

## Implemented

Each of the sixteen independent actors creates its own `PersonalAnimationTree`, graph and animation resources at runtime. The existing personal AnimationPlayer supplies the idle/walk clips; AnimationTree owns playback. Male and female walk duration and stride profiles are retained.

Graph: **idle → locomotion Blend2 ← walk TimeScale ← walk; locomotion → turning Blend2 ← turn TimeSeek ← turn; turning → output**.

The [30 September iris and stepping-turn revision](realism_turn_2026-09-30.md) records the corrected runtime eye maps, fresh Metal face/turn views, and all-sixteen checks. Costume realism and normal-speed sole contact remain open.

`parameters/locomotion/blend_amount` is driven by the actor's patrol state. Starting and stopping move the blend across 0–1 over 0.2 seconds. Each tree advances manually once per actor update, keeping movement and animation on the same time step. Disabling `movement_enabled` freezes that actor’s travel while its tree fades to idle. No direct AnimationPlayer.play calls are used for live locomotion.

The graphs are created by `characters/npcs/british/british_npc_actor.gd`; inspect PersonalAnimationTree in the remote scene while running. They are separate runtime graphs rather than shared scene resources.

## Physical body contact

### Moving body response — verified capsule contact

The moving-contact baseline found that timed patrols pushed a stationary Player along the route instead of waiting. `british_npc_actor.gd` now samples the proposed capsule motion for CharacterBody3D occupants and other British body capsules. A blocked actor holds position and patrol time while its personal tree fades to idle; clearing the obstacle resumes from the saved patrol time. Queries ignore static terrain for this response because surveyed-grade foot/terrain fitting is a separate mechanism.

The [moving-contact validation](candidates/moving_contact_validation.json) PASS for 56 front/return/side/endpoint-turn cases across the 14 active patrols. Stationary Player horizontal drift is 0 m; front/return waits reach idle and travel resumes 0.225 m after clearing the Player. Minimum capsule separation stays above the summed radii in every case. The largest sampled Player displacement per physics step is 0.0821 m, including ground settling and active side approaches.

The household system now places OfficialMan and OfficialWoman inside BritishHousehold with `movement_enabled=false`. The fixture waits for deferred household setup and pauses coach/household updates before measuring contact; its first run was invalidated by those systems relocating the officials during the exercise. They are excluded from moving-patrol cases. A fresh [stationary Player validation](candidates/player_collision_all_validation.json) still passes direct sweep and ordinary walking at all sixteen current placements, including both household residents.

Tool: `tools/characters/validate_british_moving_contact.gd`; default checks active patrols, `-- --sample` selects the first actor, `-- --actor=PrivateWoman --live` uses automatic actor updates for one resident. Headless command: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/characters/validate_british_moving_contact.gd`. Metal command adds `--rendering-driver metal --fixed-fps 60` and omits `--headless`. Reports retain automatic-update mode, current surveyed floor heights and collider paths. World runs retain existing startup lamp output and resource cleanup warnings; no script/physics errors were present in the final contact runs.

Fresh Metal contact captures show the actual Player and waiting NPC: [man](candidates/private_man_moving_wait.png), [woman](candidates/private_woman_moving_wait.png). These establish representative body spacing. Skirt clearance and sole/terrain fit remain visual defects to review; the body capsule does not describe the full dress hem. This is local waiting behavior; navigation around obstacles is not implemented.

Both Private residents pass all four cases with automatic actor updates in Forward+ Metal at a fixed 60 fps: [male report](candidates/moving_contact_private_man_live_metal_validation.json), [female report](candidates/moving_contact_private_woman_live_metal_validation.json). The external review camera explicitly restores Player visibility after the gameplay spring-arm clearance script is paused. The female-site image still shows the Player's lower legs obscured by rendered ground despite a surveyed capsule floor; that visible-ground/body alignment remains open and is not covered by capsule contact approval. Tree playback, stepping turn and full-patrol ankle-target regressions also PASS after adding local waiting.

Each preview actor now creates a torso-sized `AnimatableBody3D` capsule on collision layer 1. The capsule follows the actor's patrol transform while its personal AnimationTree continues to drive the skeleton. The dress hem remains visual cloth outside the body capsule. `sync_to_physics` is disabled on the child because its earlier enabled state left some capsules at spawn while the visible actors moved.

[All-actor capsule validation](candidates/body_collision_validation.json) PASS for all sixteen. The 30 September [full-world Player validation](candidates/player_collision_validation.json) PASS for PrivateMan and OfficialWoman, using both a 3.2 m sweep and 100 physics steps of ordinary 2 m/s walking. Both approaches remain blocked by the NPC body.

The continuation expands this to the entire roster: [all-sixteen full-world Player validation](candidates/player_collision_all_validation.json) PASS with 16/16 direct sweeps and 16/16 ordinary walking stops. Run `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/characters/validate_british_player_collision.gd -- --all`. Each NPC is held at its current patrol location during the approach; this verifies stationary body blocking throughout the placed roster.

The earlier OfficialWoman failure came from the test fixture: its fixed spawn height put the Player capsule about 0.108 m into the local terrain. The test now surveys ground height with a downward ray, starts the capsule 1 cm above it, and lets physics consume the teleported transforms before movement. No collider size or collision layer change was needed to resolve that failure.

A separate [OfficialWoman Metal validation](candidates/player_collision_metal_validation.json) also passes sweep and walking checks. The refreshed [Metal image](candidates/official_woman_player_block.png) shows her placement, but the Player mesh is absent from this framing; the image does not establish visible body contact. Moving-NPC response, crowd avoidance, cloth contact and normal-speed animation remain open.

Recheck with `tools/characters/validate_british_body_collision.gd`, `tools/characters/validate_british_player_collision.gd`, and `tools/characters/validate_british_animation_tree.gd`. Headless and Metal reports use separate files so a one-actor Metal run does not replace the two-actor report.

## Verification

[Tree validation](candidates/animation_tree_validation.json) PASS: sixteen distinct active trees and graphs, actual thigh pose playback on all sixteen, half/full start blend, half/zero stop blend, idle pose recovery and independent stop. Existing clip/facing/arm checks and full-world surveyed placement also PASS.

Fresh Metal captures below exercise tree evaluation at idle, intermediate blend and walk. Images establish representative pose appearance; normal-speed foot contact and cloth approval remain open.

### Private Man

![Tree blend 0%](candidates/private_man_tree_0.png)

![Tree blend 50%](candidates/private_man_tree_50.png)

![Tree blend 100%](candidates/private_man_tree_100.png)

### Private Woman

![Tree blend 0%](candidates/private_woman_tree_0.png)

![Tree blend 50%](candidates/private_woman_tree_50.png)

![Tree blend 100%](candidates/private_woman_tree_100.png)

## Remaining limits

The tree blends the existing preview clips. It does not add navigation, root motion, combat, gestures or cloth simulation. Skirts remain stiff and feet may slide; the torso straps, tailoring, equipment and period materials remain candidates. Motion and realism work can extend the graph after the base clips are approved.

Tools: `tools/characters/validate_british_animation_tree.gd`, `tools/characters/capture_british_animation_tree.gd`. The older walk-phase capture tool explicitly disables the tree to examine source clips; it is not evidence of live tree playback.

## Walk clip refinement

The clips now convert skeleton-space pitch/yaw into each bone's posed local axes. This removes the earlier sideways leg swing from imported bone rolls. Knee flexion, small elbow flexion and ankle counter-rotation are included; male/female stride amplitudes remain separate.

[Full-cycle gait validation](candidates/gait_validation.json) PASS for all sixteen actors: 65 samples per actor through the live tree, forward ankle swing 0.172–0.406 m, lateral drift below 0.000001 m. Vertical ankle travel is 0.018–0.043 m. These measurements are skeleton paths, not proof of mesh sole clearance, stride-speed matching or planted feet. Foot locking and normal-speed contact still need refinement.

Side-view tree evidence:

![Male side walk](candidates/private_man_tree_side_100.png)

![Female side walk](candidates/private_woman_tree_side_100.png)

## Travel-speed cadence

A walk-only TimeScale now drives cadence. Each rig is calibrated by sampling its actual ankle excursion across one cycle; estimated natural speed is twice that excursion divided by clip duration. Live cadence is travel speed divided by that estimate (bounded to 0.1–3). Idle breathing is outside this rate node. Placement offsets are initialized before measuring travel so the first frame does not cause a cadence spike.

[Cadence validation](candidates/cadence_validation.json) PASS for all sixteen: measured travel matches nominal speed × playback rate, half-speed travel produces half cadence, and stopping reaches idle with zero travel. Existing tree transition/independence and world placement checks pass again. This is an excursion-based estimate, not stance-foot locking; residual sliding, sole contact and skirt motion still need review.

Representative Metal poses after 45 live actor updates at 60 Hz:

![Male cadence](candidates/private_man_cadence_world.png)

![Female cadence](candidates/private_woman_cadence_world.png)

![Official cadence](candidates/official_man_cadence_world.png)

## Flat-ground foot planting

A per-actor two-bone stance solver now runs after tree evaluation (`characters/npcs/british/british_foot_plant.gd`). The stance ankle is held at a world target while the swing ankle clears the surveyed flat grade. A 5.5 cm hip drop blends with locomotion to preserve knee reach; ankle orientation comes from the clip. Locks release during idle and reset when facing changes. Mid-stride restarts choose a target within the remaining stance stroke.

[Full patrol foot-plant validation](candidates/foot_plant_validation.json) PASS: 610 updates per actor through outward walk, idle, return and restart, 218 locked samples each; maximum ankle-target error below 0.000001 m, no reach-limited frames and no swing ankle below its reference height. Separate tree clip tests disable this correction to verify underlying playback independently.

This validates ankle targets on the current flat plots. Mesh sole clearance, uneven ground, turn popping, normal-speed visual continuity and cloth remain unapproved. The refreshed male live cadence screenshot includes the final correction and shows a crouched/stiff gait requiring refinement. Female/official captures are from the earlier stance pass; the final capture stalled after the male view and was stopped. `foot_plant_enabled` can disable the correction per actor for clip comparison.

## Adaptive hip clearance follow-up

The fixed 5.5 cm walking hip drop is replaced by a reach calculation for the stance and swing targets. The pelvis is restored before each tree evaluation, preventing the previous correction from affecting the next frame's target calculation. Across the full patrol, men now need 0.8–2.4 cm and women 0.8 cm of hip drop, while all sixteen still hold stance targets without reach-limited frames. Tree transition and idle recovery checks pass again.

Fresh male, female and official Metal cadence views completed and were inspected. The male pose is more upright than the fixed-drop version. Hands still read stiff/open, skirts remain rigid, and snapshots do not approve normal-speed turn/contact continuity. The earlier capture-stall note above records the prior run; this fresh run completed all three views.

## Hand pose and patrol reversal

The hand preview now applies a small curl to the imported finger joints after the tree update; forearms bend slightly back toward the body. The [tree validation](candidates/animation_tree_validation.json) confirms actual relaxed finger poses on all sixteen, along with the earlier playback and independent stop checks. Close [male](candidates/private_man_hands_world.png) and [female](candidates/private_woman_hands_world.png) Metal views were inspected. Fingers look less spread, but the hands still need tailored art/skin review.

Each NPC now turns in place for 0.5 s at both patrol endpoints. Initial facing respects each actor's cycle offset. [Turn validation](candidates/turn_validation.json) PASS on all sixteen: no root translation during either turn, completed 180° facing, and expected first steps in both directions. [Male](candidates/private_man_turn_world.png) and [female](candidates/private_woman_turn_world.png) mid-turn snapshots show the current geometry; they do not prove continuous turn contact.

The personal tree now includes a dedicated turn clip, sought by endpoint progress and blended over 0.08 s. It alternately bends each hip/knee and compensates ankle pitch instead of retaining an idle leg pose through the pivot. The current turn check verifies both ankle lifts (women 2.7–3.0 cm; men 3.4–3.6 cm), full turn blend, zero root drift and correct exit headings for all sixteen. Explicit fixture types repair its earlier Godot parse failure.

A fresh Forward+ Metal recording shows the Private pair's complete patrol and both reversals: [11-second turn/patrol video](candidates/private_pair_turn_patrol_2026-09-30.mp4), with [turn frame strip](candidates/private_pair_turn_contact_2026-09-30.png) inspected. Men visibly lift a foot during reversal; the skirt obscures the woman's feet. Hands and skirts still read stiff, and this studio view does not approve sole contact or cloth deformation. Capture command: `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/characters/capture_british_motion.gd --rendering-driver metal --write-movie /tmp/tlm_british_patrol_turn_2026-09-30.avi --fixed-fps 30`; H.264 export is saved alongside the reports.

Continuation verification, 30 September 2026 11:08 IST: personal tree, turn, cadence, full-patrol foot-target and all-roster Player tests PASS. Current foot-target error stays below 0.000069 m with no reach-limited samples; male adaptive hip drop reaches 7.3 cm on some updated rigs, so the earlier 2.4 cm maximum above describes an older asset pass. The refreshed world turn captures use wider framing to show the entire male silhouette and both boots. They were captured with Forward+ Metal and inspected; the woman's skirt still prevents a direct sole-contact judgment. Next: moving-NPC response and garment/sole contact at normal speed.

## Fitted waist and latest patrol check

All eight editable pair sources now include a six-ring fitted transition from bodice to skirt. Its lower ring matches the actual skirt top vertices; [source seam validation](candidates/waist_validation.json) reports 0 m edge mismatch on each pair. All sixteen runtime models and the front, side and back turnarounds were re-exported. This closes the earlier open waist gap at the source mesh, but the connector still reads as a hard horizontal band in [Private](candidates/private_woman_waist_back.png), [Captain](candidates/captain_woman_waist_back.png), and [Official](candidates/official_woman_waist_back_wide.png) Metal rear views. The Official woman was moved onto the open paved path because the raised garden border obscured her skirt in the prior view.

Military men's preview routes were shortened from 1.1 m to 0.9 m to keep knee targets within reach; the Official man's route remains 0.5 m and women's routes 0.9 m. Post-export [full patrol foot-plant](candidates/foot_plant_validation.json), [cadence](candidates/cadence_validation.json), [tree](candidates/animation_tree_validation.json), [turn](candidates/turn_validation.json), [world placement](candidates/roster_world_validation.json), and [runtime separation](candidates/roster_runtime_validation.json) checks PASS for all sixteen. These structural checks do not approve sole-to-terrain contact, cloth behavior, tailoring or normal-speed motion.

## Scalp-fitted headwear — 30 September

All eight men and the three bonnet-wearing women now have headwear fitted from each evaluated MPFB scalp. The previous crowns were roughly twice scalp width and centered behind the head. Crown width/depth now follow the upper scalp bounds with 8 mm clearance per side, and the crown base overlaps the upper head by 45–55 mm. The Official's top-hat cylinder is fitted separately from its wider brim. Existing cap bands, visors and bonnet brims follow the same adjustment.

[Exported headwear validation](candidates/headwear_validation.json) PASS for all 11 headwear actors: every exported cap, band, visor, bonnet and top-hat vertex has full head-bone weight. They follow the head rigidly during the personal clips. All 8 editable pairs, 16 runtime exports, manifests and 24 source turnarounds were refreshed. Private front, Corporal side and Official front renders were inspected; caps sit close to the head. The Official's donor hair still protrudes around his hat and covers part of his face, so hair/costume approval remains open.

The waist bridge now gathers fullness close to the skirt edge and uses smooth shading, reducing the broad band in the Private rear view. The skirt join still has a visible seam and requires tailoring. The [updated 11-second Metal patrol](candidates/private_pair_patrol_2026-09-30.mp4) includes the fitted Private headwear and both stationary turns; [mid-turn frame](candidates/private_pair_turn_review.png) inspected. This is a rendered flat-ground studio recording with fixed 30 fps playback, not final world or sole-contact approval.

Tools: `tools/characters/fit_british_headwear.py`, `tools/characters/validate_british_headwear.py`, `tools/characters/bridge_british_waists.py`, `tools/characters/capture_british_motion.gd`. Next: hair clearance under hats, skirt join and mesh sole contact in moving world approaches.
