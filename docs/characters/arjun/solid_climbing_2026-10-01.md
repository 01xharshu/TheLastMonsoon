# Solid climbing and grip rework — 2026-10-01

The owner rejected the earlier climbing motion, reported twisted palms, and required solid walls throughout climbing. The earlier 13-second preview is superseded by this pass.

## Collision and body clearance

`player/climb_collision.gd` provides collision-checked travel shared by tall walls, ledges and windows. World collision stays enabled; movement uses `move_and_collide` instead of assigning the body's world position. Route sweeps reject obstructed climbs before starting. If a new obstruction blocks a sweep, progress pauses instead of advancing through it. The climb uses a compact capsule fitted to its crouched pose; standing collision restores only after a separate clearance query confirms it fits. The ledge capsule follows the crouched torso above the hips. Saved collision resources and offsets restore at completion.

The visual layer also checks pelvis, chest, head and shoulder clearance against the solid face and coping before solving hand/foot contact. This prevents the animated torso from leaning through masonry outside its collision capsule. These are calibrated bone envelopes, not a complete cloth/mesh collision simulation. The window aperture remains traversable while its sill, jambs and shutter stay solid.

## Grip and AnimationTree

Tall masonry has 0.40-m stone spacing and 11 rows. Foot targets were lowered; both sole targets remain planted during pushes. The fixture uses 17 reach/boot/push steps at 0.55 seconds per cycle, taking 14.61 seconds including entry and mantle. The AnimationTree now includes a separate `mantle_press` pose between hanging and the crouched step. Whole-model forward tilt was removed because it doubled the tree's spine bend.

Hands use the rig's measured palm frame. Forearm pronation and a downward elbow pole replace wrist-only twisting. Wrist deviation is limited to 0.70 rad during ascent and up to 1.20 rad during the mantle press. Finger outer joints hook the stone, then relax as the hands press at the coping. Previously a wrist reached 2.87 rad and visibly pinched the skin.

## Fresh evidence and checks

- Complete Metal sequence (test output deleted): 439 fixed-interval simulation frames rendered with Forward+/Metal and encoded at 30 fps. Grip close-up (test output deleted), supporting press (test output deleted), crouched transfer (test output deleted).
- Rendered fixture PASS (test log deleted): world collision enabled throughout; zero body-shape overlaps with masonry; placement pauses, held targets, completion and standing restoration. Ascent push palm-center gap <0.000001 m, calibrated boot-sole gap 0.0026 m, wrist deviation <0.699 rad.
- Real-time contact PASS (test log deleted): same collision and contact gates after the final visual solve, palm-center gap 0.000211 m and sole gap 0.0026 m. Measuring before the visual solve had previously reported a stale 0.020-m sole gap.
- Solid-wall sweep PASS (test log deleted): a requested motion through the slab is blocked; crouching can clear the top; standing expansion is refused until legs clear it.
- Object Metal PASS (test log deleted): low/high profiles, sampled palms, rotated ledge landing and narrow-lip rejection. Low and high pose captures in `object_climb_2026-10-01` were inspected after the collision change.
- World window PASS (test log deleted): all eight registered windows remain traversable. The isolated window check also passes both directions, boot/head clearance, blocked landing and closed shutter.
- World wall route PASS (test log deleted): supporting boot, forward knee bend, palm contact and wall-walk landing. The motion-tree regression verifies distinct mantle press; shared firearm grip regression PASS. The world/firearm checks still print shutdown resource warnings after their explicit PASS results.

The rendered sequence is deterministic fixture playback; it does not establish interactive world frame rate. Final animation quality, full-world player camera, finger pressure, complete boot/cloth surface contact and owner appearance/motion acceptance remain open. Numeric target contact does not establish those gates.
