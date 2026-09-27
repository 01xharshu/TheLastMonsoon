# British NPC AnimationTree

## Implemented

Each of the sixteen independent actors creates its own `PersonalAnimationTree`, graph and animation resources at runtime. The existing personal AnimationPlayer supplies the idle/walk clips; AnimationTree owns playback. Male and female walk duration and stride profiles are retained.

Graph: **idle (0) → locomotion BlendSpace1D ← walk (1) → output**.

`parameters/locomotion/blend_position` is driven by the actor's patrol state. Starting and stopping move the blend across 0–1 over 0.2 seconds. Each tree advances manually once per actor update, keeping movement and animation on the same time step. Disabling `movement_enabled` freezes that actor’s travel while its tree fades to idle. No direct AnimationPlayer.play calls are used for live locomotion.

The graphs are created by `characters/npcs/british/british_npc_actor.gd`; inspect PersonalAnimationTree in the remote scene while running. They are separate runtime graphs rather than shared scene resources.

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
