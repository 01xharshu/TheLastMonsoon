# Women’s morning river routine

Updated 2026-10-05 12:56 IST; chat/root. **IN_PROGRESS: animation/contact study advanced; final cloth, motion, real-bank and world approval remain open.**

Scope: adult village women depart together, fill water pots, wash clothing, sit and converse, pick up the filled pots, return home and deliver them. Uses the existing MakeHuman/MPFB village-woman body and rig. The original MPFB donor, static playable woman and shared village exporter remain unchanged. No human was constructed from primitives.

## Current implementation

- `characters/npcs/indian/river_woman_study.gd`: independent idle/walk AnimationTree plus procedural contact action poses. Dedicated candidate loader; figure facing corrected. Additive poses reset before evaluation. Two-bone solve in `river_contact_solver.gd` without limb stretch or bone translation. Wrist targets are not proof of palm/finger surface contact.
- 13 stages, 72-second demonstration: depart 10s, arrive 2s, lower pot 3s, fill 5s, lift 3s, wash 12s, sit 3s, talk 10s, stand 3s, pick up pot/turn 4s, return 10s, deliver 3s, home 4s. Playback adds one final home second.
- Both hands reach the pot; mouth is tilted into the fixture water (mouth y≈0.00548 m, surface y=0.01 m). Open-mouthed clay profile replaces the closed sphere/cylinder. Pot stays parked during conversation; separate pickup and turn prevent teleportation or unreachable reach. Filled-water state remains with the delivered pot.
- Wash includes rub, rinse and wring phases with smooth target changes and a sagging/twisting cloth mesh. Member phase offsets vary gait and wash cadence; speaking gestures alternate across the three members. Knees use forward poles; ankle targets remain on the fixture floor while pelvis lowers/rises. Stance cadence is matched to the shortened 0.4 m/s flat route, not terrain navigation.
- `river_routine_review.gd/.tscn`: three separate adult MPFB rigs and trees on a four-metre flat review route. No day clock, save-state scheduling, production collision or real village route is implemented.

## Retained source and clothing study

Builder: `tools/characters/build_river_woman_candidate.py`.

Source: `WorkingAssets/NPCs/river_woman/river_woman_motion.blend`.

Runtime study: `WorkingAssets/NPCs/river_woman/river_woman_rigged_candidate.glb`; SHA manifest in the same directory.

The donor pallu was bound to nonexistent `spine01`; repaired via native-body weight transfer. Lower sari/border/pallu now have support topology and blended body-derived leg/torso weights, so they deform during crouch and sitting. No physique substitution. Complete original MPFB body retained in source, with a 310-face opaque fitted bra/brief foundation derived from its own surface. Foundation is retained for fitting review but excluded from the clothed export as fully covered. Foundation shape/coverage is not final approved. Blouse uses plain cotton; donor covered-skin mask retained/conservatively tightened. Remaining blouse/body breakthrough shows this still needs actual fit work.

## Verification

1. `/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/characters/build_river_woman_candidate.py` succeeded. Log: `/tmp/tlm_river_candidate_build.log`.
2. `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/characters/validate_river_routine.gd` **PASS**: 13 stages, independent trees, water/delivery/laundry lifecycle, additive reset, 75-second 30Hz sweep across all three rigs. All solved wrist/ankle target errors stay within the 15 mm gate. Report: `river_routine_validation.json`; log `/tmp/tlm_river_routine_contact.log`. This measures bone-tip targets only, not rendered palms, garment contacts, soles, joint limits, terrain or hardware performance.
3. `/Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/characters/capture_river_routine.gd` succeeded without script errors on Godot 4.7.2 Forward+/Metal Apple M4. Nine current samples: `river_depart.png`, `river_fill.png`, `river_wash.png`, `river_rub.png`, `river_rinse.png`, `river_wring.png`, `river_talk.png`, `river_pickup.png`, `river_return.png`. Log `/tmp/tlm_river_routine_contact_metal.log`.
4. Same command with `-- --record` produced 1095 frames at 15fps; encoded `river_routine_motion.mp4`: 854×480, **73 seconds at simulated 1.0x**, 1.07 MB. Command: `ffmpeg -framerate 15 -i /tmp/tlm_river_routine_frames/frame_%04d.png -frames:v 1095 -c:v libx264 -crf 22 -pix_fmt yuv420p -movflags +faststart docs/characters/npcs/river_routine_motion.mp4`. Log `/tmp/tlm_river_routine_sequence.log`; hashes/scope `river_routine_evidence.json`. Full native-window capture stalled off-focus; final capture uses a fixed SubViewport and `RenderingServer.force_draw(false)`, matching the target Metal renderer. Fixed-step playback is not measured native FPS. Temporary source frames removed after verified encode.
5. Inspected fresh action captures and extracted video frames at fill, talk and return. Sari now follows seated/crouched legs, but pinching/angular folds and intersections persist; upper blouse/skin defects, finger/palm contact, cloth clearance, mass/weight transfer and conversation polish are not approved. No claim of a fully accepted 1.0x motion review or actual bank traversal.
6. `git diff --check` PASS. Shared `python3 tools/check_agent_docs.py` fails because the current concurrent root ledger exceeds 6000 characters (last observed 6212); unrelated entries preserved.

## Exact next action

Open the retained river source, repair blouse clearance/masking and create seated/crouched sari/pallu corrective shapes over this same authoritative MPFB body/foundation. Verify those shapes and skin weights survive GLB export. Inspect close front/side/rear full 1.0x cycles, actual palm/finger grips, sole planting and loaded-gait balance on the real river bank. Only after clothing/contact passes, survey collision-safe home routes and integrate morning/day/save behavior in Bhairavpur. Keep the current live population unchanged until that evidence exists.

## Continuation — 2026-10-07 15:30 IST, /root, IN_PROGRESS

Objective: complete native body/foundation retention, posed cloth fit, real-bank morning route and save integration. Added `tools/characters/export_river_poses.gd` (97 sampled runtime skeleton poses), `river_cloth_correctives.py`, runtime interpolation and removed torso masking/foundation export exclusion in the builder. Blender build running: `/tmp/tlm_river_cloth_build.log`. Source/rest body retained; clothing-only collision corrections do not alter physique. Next: inspect rebuilt moving pixels, integrate a grounded village-to-ghat route and test schedule/save/contact. Historical mask/excluded-foundation notes above are superseded by the current full-body contract.

15:40 IST milestone: Blender build succeeded (`/tmp/tlm_river_cloth_build.log`), 97 correction keys per outer garment and foundation now exported. Added `village_river_routine.gd`, `river_routine_save.gd`, one VillageStreetLife child and two save-manager hooks, preserving other dirty changes. Runtime actor accepts route/terrain/water overrides. Next: parser/contact/render checks and physical route/save sweep; integration is not verified yet.

15:29 IST verification: revised flat-fixture 75s/30Hz target sweep PASS; fresh Metal nine-shot render inspected (blouse coverage improved, sari remains angular). First live test exposed unnamed collider-child lookup; fixed with explicit BodyShape name. Real-bank endpoint is (80.11087,0.03,166). Retained audited body node name and 14517 runtime body vertices; foundation included. Next: rerun live route/save test, moving cloth/contact review.
