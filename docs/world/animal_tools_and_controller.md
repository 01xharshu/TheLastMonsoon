# Animal asset workflow and DualSense foundation

Updated 2026-09-24. The current procedural horse body is a rough game candidate. A rig generator can speed animation setup, but it cannot turn that mesh into accurate horse anatomy on its own.

## Tools checked

- **Rigify Horse metarig: available in the installed Blender 5.2 package.** Blender's [Rigify manual](https://docs.blender.org/manual/en/latest/addons/rigging/rigify/basics.html) lists Horse and Basic Quadruped templates. The local `rigify/metarigs/Animals/horse.py` exists. Rigify supplies an editable control rig once its bones are fitted to a body; it does not generate the body's surface, textures, tack, or historically appropriate type.
- **Animal Animator: available from the [Blender Extensions catalog](https://extensions.blender.org/add-ons/animal-animator/versions/), not installed locally.** Its first release is listed as 0.1.0 (2026-07-30), GPL-3.0-or-later, Blender 4.2+, with a horse rig animation workflow. This may accelerate motion tests after a suitable skinned body exists. Its own listing says the initial release was not extensively tested; Godot export, quality, and project compatibility have not been verified.
- **MPFB: installed, but human-only.** The [official extension listing](https://extensions.blender.org/add-ons/mpfb/) describes a human character generator. No comparable, verified one-click parametric horse body generator was found in this review.

Recommended next asset candidate: start from an anatomically credible, editable horse mesh with confirmed redistribution rights, fit the Rigify Horse metarig, weight and deform it, bake walk/trot/canter/gallop/stop/jump actions, then export an isolated Godot candidate. Keep the present horse until source, licence, tack/rider contact, motion, and rendered appearance pass review. The same approach can supply horse and bullock bodies for later period carts, with species-specific rigs and harnesses.

## Controller status

Godot 4.7 uses [SDL 3 controller mappings on desktop](https://docs.godotengine.org/en/4.7/tutorials/inputs/controllers_gamepads_joysticks.html) and recommends action mappings for keyboard and controllers. `project.godot` now maps both sticks and core actions for the common DualSense layout: left stick moves/steers, right stick looks, Cross jumps, Square interacts, Triangle mounts/dismounts, L3 sprints/gallops, Options pauses, Create opens inventory, R3 toggles view, and D-pad down uses water. Horse gallop now reads the shared sprint action; the pause menu can close through the pause action and focuses Resume when opened.

`tools/world/validate_controller_map.gd` checks the action map without hardware. Horse riding and menu navigation checks pass with these changes. **A physical DualSense has not been connected or tested.** Weapon aiming/firing, weapon wheel, map, save/load/menu navigation beyond initial focus, context prompts, trigger pressure, vibration, and platform-specific glyphs still need controller work and device review. These are required before claiming complete DualSense compatibility.
