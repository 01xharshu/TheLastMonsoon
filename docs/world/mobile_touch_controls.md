# Mobile touch baseline — 2026-10-08 IST

Shared Android/iOS overlay integrated in `player/player.tscn`, implemented in `ui/mobile/touch_controls.gd`. Desktop hides it unless launched with `--touch-controls` after Godot's `--` separator. Preview enables mouse-to-touch emulation; actual simultaneous fingers require a touch device or synthetic tests.

Left joystick sends analog movement strengths; right open area drags the existing camera pivot with pitch limits. Held buttons use shared gameplay actions: jump, interact, ride/secondary interaction, sprint, aim, attack, reload, crouch, prone, next weapon, stow and water. Bag, Map and Pause remain accessible above the gameplay controls. Opening blocking menus/actions, focus loss, resizing or teardown releases owned input. Pause calls the existing GameMenu, including Resume while the tree is paused. Native safe-area insets supplement conservative edge margins. Synthetic InputEventAction dispatch bypasses keyboard/controller event filtering without changing saved device preferences.

Validation: player PackedScene loads; isolated reusable test passes movement, simultaneous jump, camera direction/clamp, touch release, menu cleanup, focus cleanup and deadzone. Native Metal isolated overlay rendered and reviewed: joystick lower left, readable action grid lower right, menu buttons upper right. Temporary capture deleted. Test exits with two ObjectDB leak warnings in the project environment; not resolved by this baseline. These checks do not establish full-world touch usability or real-device performance.

Run check:
`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/world/validate_mobile_touch.gd`

Desktop preview:
`/Applications/Godot.app/Contents/MacOS/Godot --path . -- --touch-controls`

Start/Continue, then test joystick movement; drag open right area to look; hold Use for a hold interaction; open/close Bag and Map; Pause/Resume; verify no movement remains held. Desktop mouse preview supports one finger only. Keyboard/controller still works.

Open: Android export tooling/build and real-device run; iOS Xcode/signing/build and real-device run; mobile renderer/quality and memory/loading optimisation; phone menu/HUD fit and map gestures; touch-specific prompts; button layout customisation/context reduction; validation of complete combat, riding, climbing and swimming routes. No installable phone build or mobile performance approval yet.
