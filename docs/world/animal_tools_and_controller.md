# Animal asset workflow and DualSense foundation

Updated 2026-09-24. The current procedural horse body is a rough game candidate. A rig generator can speed animation setup, but it cannot turn that mesh into accurate horse anatomy on its own.

## Tools checked

- **Rigify Horse metarig: available in the installed Blender 5.2 package.** Blender's [Rigify manual](https://docs.blender.org/manual/en/latest/addons/rigging/rigify/basics.html) lists Horse and Basic Quadruped templates. The local `rigify/metarigs/Animals/horse.py` exists. Rigify supplies an editable control rig once its bones are fitted to a body; it does not generate the body's surface, textures, tack, or historically appropriate type.
- **Animal Animator: available from the [Blender Extensions catalog](https://extensions.blender.org/add-ons/animal-animator/versions/), not installed locally.** Its first release is listed as 0.1.0 (2026-07-30), GPL-3.0-or-later, Blender 4.2+, with a horse rig animation workflow. This may accelerate motion tests after a suitable skinned body exists. Its own listing says the initial release was not extensively tested; Godot export, quality, and project compatibility have not been verified.
- **MPFB: installed, but human-only.** The [official extension listing](https://extensions.blender.org/add-ons/mpfb/) describes a human character generator. No comparable, verified one-click parametric horse body generator was found in this review.

Recommended next asset candidate: start from an anatomically credible, editable horse mesh with confirmed redistribution rights, fit the Rigify Horse metarig, weight and deform it, bake walk/trot/canter/gallop/stop/jump actions, then export an isolated Godot candidate. Keep the present horse until source, licence, tack/rider contact, motion, and rendered appearance pass review. The same approach can supply horse and bullock bodies for later period carts, with species-specific rigs and harnesses.

## Controller status

Godot 4.7 uses [SDL 3 controller mappings on desktop](https://docs.godotengine.org/en/4.7/tutorials/inputs/controllers_gamepads_joysticks.html) and recommends action mappings for keyboard and controllers. `project.godot` now maps both sticks and core actions for the common DualSense layout: left stick moves/steers, right stick looks, Cross jumps, Square interacts, Triangle mounts/dismounts, L3 sprints/gallops, Options pauses, Create opens inventory, R3 toggles view, and D-pad down uses water. Horse gallop now reads the shared sprint action; the pause menu can close through the pause action and focuses Resume when opened.

`tools/world/validate_controller_map.gd` checks the original action map without hardware. Horse riding and initial menu navigation checks passed with those changes. **A physical DualSense has not been connected or tested.** The additional software mappings and remaining review limits are below.

## Device choice and additional controls (2026-09-24)

Settings now offers Auto, Keyboard + Mouse, and PS5 DualSense. The choice persists in `user://settings.cfg`. Auto starts with a connected controller when present, switches to keyboard/mouse after a meaningful key, click, or captured mouse move, and switches back after a controller button or substantial stick motion. A controller disconnect falls back to keyboard/mouse. A manually selected controller also falls back when none is connected. Gameplay actions are filtered to the active device; built-in UI navigation remains available from either device so the player can always reach Settings.

Shared actions now cover left/right trigger aim and attack, Circle reload, D-pad right hold for the weapon wheel with left-stick selection, D-pad left for the map, and D-pad up to stow. On the map, left stick pans, right stick zooms, Cross places a waypoint at the centre, Circle closes, and Triangle resets. Main and pause menus give initial focus; the inventory focuses its first available action. `tools/world/validate_input_device_switch.gd` checks both action routes, Auto handoff, and saved preference without hardware.

## DualSense coverage and feedback (2026-09-24)

| Control | Gameplay use |
| --- | --- |
| Left / right sticks | Move and look; left stick pans the map and chooses a wheel sector; right stick zooms the map. |
| L3 / R3 | Sprint or gallop / toggle view. |
| Cross / Square / Triangle / Circle | Jump or confirm / interact / mount or dismount / reload or back. |
| L1 / R1 | Hold L1 with Square for a secondary world interaction, including filling the water pouch / cycle to the next owned weapon. |
| L2 / R2 | Aim or draw / fire or strike. |
| D-pad up / down / left / right | Stow or draw / drink carried water / map / hold weapon wheel. |
| Create / Options / touchpad click | Inventory / pause / identity scroll. |

The map also uses Cross to place a centred waypoint, Circle to close and Triangle to reset. Circle returns from title/pause subpages. The microphone/mute and PlayStation system buttons are not assigned gameplay actions because SDL or the OS may reserve them or expose them inconsistently; they are not required to finish a game flow. Touchpad position/gestures are not used, so a simple click remains sufficient.

`systems/controller_feedback.gd` uses [Godot's rumble API](https://docs.godotengine.org/en/4.7/tutorials/inputs/controllers_gamepads_joysticks.html) for short shot, bow, melee, jump, interaction, mount and water cues. Settings provides a strength slider, including zero, and a test button. A supported LED shows blue normally, amber when stamina or hydration falls below half, and red below one quarter, using [capability detection and the light API](https://docs.godotengine.org/en/4.7/tutorials/inputs/controller_features.html). LED use can be disabled. Optional gyro aim works only during aiming and after the player initiates the one-second flat-surface calibration in Settings. The right stick always remains available. Settings shows the detected controller name and rumble/light/motion capabilities.

**Hardware review remains required.** No DualSense was connected for this pass. Godot action and scene checks establish the software paths, not physical button labels, Bluetooth/USB output, vibration feel, gyro axes/sensitivity, focus across every menu, or a complete playable route. The [Godot 4.7 controller feature API](https://docs.godotengine.org/en/4.7/tutorials/inputs/controller_features.html) documents rumble, LEDs and motion sensors but does not provide a standard adaptive-trigger effect; that feature needs a separate platform integration and device validation. The controller speaker, microphone and advanced touchpad gestures have no gameplay dependency or verified implementation.
