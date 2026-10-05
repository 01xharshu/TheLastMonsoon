# Fort staff clothing and hand-to-latch motion

Updated 2026-10-05 IST. The runtime clothing and contact-driven latch sequence are implemented. Native visual review and targeted checks pass; finished cloth tailoring, individual staff likeness and owner play approval remain open.

## Staff clothing

The cook and steward reuse the existing MakeHuman/MPFB farmer rig from `WorkingAssets/NPCs/village_farmer/village_farmer_rigged_candidate.glb`. No human body or placeholder was constructed procedurally. The editable MPFB source and `tools/characters/build_village_farmer.py` remain the rebuild authority.

Instance-only fabric shaders now cover the actual imported upper, dhoti, wrap and border meshes. The cook has worn undyed cotton and a stained work apron; the steward has a muted green upper garment and a contrasting wrap. Fine yarn response is filtered to avoid distant shimmer. Pointed shirt tails are trimmed beneath a continuous folded hem. The apron has neck straps and uses the source skin binding, with pelvis/spine weights rather than nearby sleeve weights; it no longer stretches with the arms. Apron clearance was increased to cover the underlying garment throughout the lean. These changes live in `characters/npcs/households/fort_staff_clothing.gd` and `fort_staff_fabric.gdshader`; the shared farmer export remains intact.

The cook's targets were uncrossed, his left rim target raised slightly and his forward working lean adjusted to 0.42 radians. The full stir-cycle check records a maximum palm gap of approximately 11 mm and minimum hand separation of approximately 242 mm. The current silhouettes remain simple, and head-wrap fit, cuffs, apron ties and continuous close-up cloth contact warrant further art refinement. The two staff still share the farmer's facial identity.

## Latch sequence

`player/door_latch_action.gd` sequences a collision-aware approach, reach, finger closure, contact-triggered release and recovery. A right-palm solver uses the actual visible pull ring. Weapons are stowed before contact. Character input movement waits while the action is active; failed approaches or unreachable hands release control without opening the door.

The door stays still until measured palm contact is within 40 mm. The tested release pose reaches the ring within 1 mm. Opening selects a direction away from Arjun. Closing includes a retreat toward the clear side before requesting movement, using the player's existing step-up/down handling for raised thresholds; existing swept-character checks still prevent unsafe closure. The player can use interior pulls to leave a night-latched house, while an exterior night latch rejects the gesture. Open-door prompts aim at the visible pull on a leaf, requiring the player to face it.

Wooden shutters sit within the wall reveal rather than on the exterior plane, with lower reachable latch hardware. This prevents a standing player from having to press through the sill wall to reach an interior latch. Save data retains opening direction as well as open/closed state, accepting the previous boolean entries for older saves. This is authored procedural body/hand motion, not a captured animation clip. The grip releases early in the swing rather than tracking a wide leaf through its entire travel.

## Evidence

- [Focused result](staff_latch_validation.json), `tools/world/validate_staff_latch.gd`: normal E, approach/reach/release/recovery, exterior rejection, inside exit, closing clearance, serialized direction, legacy saves, clothing/skin bindings and 180 contact samples PASS. Fresh Metal log: `/tmp/tlm_staff_latch_metal_final_oct5.log`.
- [Latch contact](captures/arjun_door_latch_contact.png), [open leaves](captures/arjun_door_latch_open.png), [staff clothing](captures/fort_staff_clothing_detail.png): latest native views replace prior captures of these same views. Reviewed visible ring reach, continuous hems, apron placement and uncrossed hands. The staff review stage omits kitchen furniture to expose the costume.
- [Native motion preview](captures/staff_latch_motion.mp4): sampled sequence evidence, including gesture and recovery. Render sampling compresses elapsed simulation time; this clip is not evidence of final 1.0x pacing or player-camera feel.
- Full-slot restore PASS, including manual shutter opening direction: [save result](save_flow_validation.json), `/tmp/tlm_latch_save_final_oct5.log`. Main-world follow-up: `tools/world/validate_fort_realism.gd`, `tools/world/validate_save_flow.gd`; logs `/tmp/tlm_fort_latch_clean_oct5.log` and `/tmp/tlm_latch_save_final_oct5.log`. Check their final reports before claiming current integrated PASS. Earlier runs were affected by concurrent map/interaction parser failures; the remaining marker threshold reference was repaired using squared distance, preserving the ongoing optimisation.

Next: final cloth and latch pacing review in the player camera, including doorway clutter, all gate sizes, cuffs/straps and spoon contact. Refresh integrated reports after any concurrent world changes. Structural/contact checks do not approve final realistic appearance or motion.
