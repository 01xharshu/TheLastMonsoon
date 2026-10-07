# Arjun combat, rescue and animation

Updated 2026-10-06 01:52 IST; /root. Status: IN_PROGRESS. Playable combat/rescue/arrest baseline and focused contact fixes are integrated. Final character realism, clothing review across all gameplay and target-hardware performance remain open.

## Current implementation

Arjun uses his live AnimationTree for alternating punches, ground and airborne kicks, knife stab, sword swing, guard, hit reaction, dodge and rear restraint. Existing locomotion, swimming, seated and firearm/reload branches remain integrated. Click attacks; double-click kicks; X dodges with stamina and collision checks; stowed-weapon aim guards; B starts/cancels a rear hold. Rear restraint blends into a nonlethal knockout with paired palm/collar contact and collision-checked approach. Weapons can kill hostile receivers.

Explicit attacker/faction damage policy protects Indian civilians from Arjun's fists, blades, arrows and bullets. Their physical bodies stop shots. The British-private encounter near (322.5, ground, 151) uses actual fist contact to injure a clearly adult shirtless peasant wearing an opaque dhoti. The peasant falls alive and recovers after rescue. Three police patrols use individual road routes, sight checks and alert markers, pursue and attack, capture from behind, allow four Space presses to escape, and continuously escort Arjun through the station to custody and release.

Running contact caches leg bones and real boot/outsole support points once. Low stance feet retain supported world targets; swinging feet receive floor clearance without stance pinning. Air, turn, kick, dodge, paired, seated and mounted transitions release the applicable constraints. No mesh reconstruction occurs per frame.

NPC damage capsules follow their posed torso/head during falls. Fall height is actor-relative; incoming rotations ease into new reactions. Down actors stop their animation/combat/vitality processing after settling. Knife/sword/restraint controllers sleep when idle; awareness is staggered at 4 Hz. Audio cleanup repairs apply to test shutdown only.

## Bodies and clothing

Original Arjun GLB SHA256 remains `0bd3301a1b06c49d56a204f679ab45463e83e62f0696f71035988f9323d3dd0f`; likeness/source replacement is outside this combat change. Owned garment-only yoke and opaque foundation share the live skeleton, with a fitted waist/crotch panel closing the raised-knee gap. Editable complete-body source: `WorkingAssets/Arjun/combat_clothing/upper_trouser_yoke.blend`; runtime: `characters/arjun/combat_trouser_yoke.glb`; builder: `tools/characters/build_combat_trouser_yoke.py`. The yoke audit checks export/fitting hashes and skin contracts; it does not independently audit Blender body retention.

Peasant source: `WorkingAssets/NPCs/rescue_peasant/rescue_peasant.blend`; runtime: `characters/npcs/rescue_peasant.glb`; builder: `tools/characters/build_rescue_peasant.py`. Complete anatomical body and separate opaque foundation remain. Dhoti floor compression is a cloth-only corrective, default zero and active in fall/down poses; it does not change the body.

## Verification and evidence

- Latest native arena: `COMBAT RESCUE PASS []`, `/tmp/tlm_combat_rescue_final_current_2026-10-06.log`. Verifies actual fists/blades, once-per-receiver wounds, protected civilians/physical bullet blocking, guard/dodge, paired palms, knockout, horizontal fallen receivers/rays, gun lethality and idle sleep. Report: `combat_rescue_validation_metal.json`.
- Running CPU skin/contact regression: PASS, `/tmp/tlm_combat_running_turn_stop_final_2026-10-06.log`, `running_sole_contacts.json`. 117 support samples; actual boot/outsole minimum approximately 8 mm through sprint/turn/stop; jump releases contacts. This is contact evidence, not final gait approval.
- MotionTree, clothing and seated-rider regressions PASS; latest logs `/tmp/tlm_combat_tree_soles_final_2026-10-06.log`, `/tmp/tlm_combat_clothing_layer_final_2026-10-06.log`, `/tmp/tlm_combat_rider_final_current_2026-10-06.log`.
- Independent source/export audits: `python3 tools/characters/audit_rescue_peasant.py` and `python3 tools/characters/audit_combat_yoke.py`; reports `rescue_peasant_full_body_validation.json`, `combat_yoke_validation.json`.
- Full actual-world behavior PASS headless and Metal: `/tmp/tlm_combat_world_verified_2026-10-06.log`, `/tmp/tlm_combat_world_metal_zero_final_2026-10-06.log`. Reports `combat_world_validation.json` and `_metal.json`. Rescue, three routes, personal sight/marker, rear escape, continuous escort, cell and release verified; maximum escort step 0.020717 m. These world captures precede the final hero waist/sole refinement.
- Current 1.0x review: `combat_motion_1x_2026-10-06.mp4`, 600 native-rendered frames, 30 Hz, 20 seconds, 1280×720. Metadata: `combat_motion_review_2026-10-06.json`. Inspected raised-knee, rear release, sprint and floor views. Offline fixed-rate rendering does not measure hardware FPS.
- Latest world images: `combat_world_beating_2026-10-06.png`, `combat_world_fallen_peasant_2026-10-06.png`, `combat_world_rescue_2026-10-06.png`, `combat_world_patrol_alert_2026-10-06.png`, `combat_world_capture_2026-10-06.png`.
- Coordinator-only measured p95: headless 134 µs, Metal 168 µs, 90 samples. Whole-game performance remains unverified. Test audio cleanup removes prior retained-playback shutdown warnings.

## Remaining scope and exact next action

Continue close 1.0x gait/hand/cloth review in the actual city with the final hero waist/sole changes, particularly acceleration, planted turns, rear-hold release and down-pose leg/boot contact. Refine authored motion where pixels show defects; cached contact solves and structural PASS do not grant final realistic acting or clothing approval. Then measure full-world CPU/GPU/memory on target hardware with an uncontended matched setup. Active crime/grapple/custody save/load and owner approval remain open.

Run `/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-driver metal --fixed-fps 60 --script res://tools/world/capture_combat_encounters.gd` to refresh city evidence; inspect actual pixels before approval. Preserve other owners' assets and processes. Root handoff currently exceeds the shared 6000-character budget; only this task's compact entry was updated. Iteration history is retained in `docs/agent/history/2026-10-06-arjun-combat-contact-iterations.md`.
